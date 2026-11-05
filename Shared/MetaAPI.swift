import Foundation

enum MetaError: LocalizedError {
    case tokenInvalid(String)
    case api(String)

    var errorDescription: String? {
        switch self {
        case let .tokenInvalid(name):
            return "Der Meta-Zugang für \(name) ist abgelaufen. Bitte in der App neu verbinden."
        case let .api(message):
            return "Meta: \(message.prefix(200))"
        }
    }
}

/// Minimal client for the Facebook and Instagram Graph APIs.
enum MetaAPI {
    static let version = "v24.0"
    static let periodDays = 28
    static let postCount = 3

    private static func base(_ host: MetaHost) -> String {
        switch host {
        case .facebook: return "https://graph.facebook.com/\(version)"
        case .instagram: return "https://graph.instagram.com/\(version)"
        }
    }

    // MARK: Requests

    private static func get(
        _ host: MetaHost,
        _ path: String,
        _ params: [String: String],
        token: String,
        accountName: String = "dieses Konto"
    ) async throws -> [String: Any] {
        var components = URLComponents(string: "\(base(host))/\(path)")!
        components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            + [URLQueryItem(name: "access_token", value: token)]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unbekannter Fehler"
            // 190: token invalid or expired, 102: session expired.
            if let code = error["code"] as? Int, code == 190 || code == 102 {
                throw MetaError.tokenInvalid(accountName)
            }
            throw MetaError.api(message)
        }
        guard (200..<300).contains(status) else {
            throw MetaError.api("HTTP \(status)")
        }
        return json
    }

    // MARK: Connecting accounts

    /// All Pages (and their linked Instagram accounts) a user or system user token can manage.
    /// Page tokens taken from a long-lived user token do not expire.
    static func discoverAccounts(userToken: String) async throws -> [MetaAccount] {
        let json = try await get(.facebook, "me/accounts", [
            "fields": "id,name,access_token,instagram_business_account{id,username}",
            "limit": "100",
        ], token: userToken)
        var accounts: [MetaAccount] = []
        for page in json["data"] as? [[String: Any]] ?? [] {
            guard let id = page["id"] as? String,
                  let token = page["access_token"] as? String else { continue }
            let name = page["name"] as? String ?? id
            accounts.append(MetaAccount(id: id, platform: .facebook, name: name, token: token, host: .facebook))
            if let ig = page["instagram_business_account"] as? [String: Any],
               let igID = ig["id"] as? String {
                accounts.append(MetaAccount(
                    id: igID,
                    platform: .instagram,
                    name: ig["username"] as? String ?? igID,
                    token: token,
                    host: .facebook
                ))
            }
        }
        return accounts
    }

    /// An Instagram account connected through "Instagram API with Instagram Login",
    /// for accounts that are not linked to a Facebook Page.
    static func instagramLoginAccount(token: String) async throws -> MetaAccount {
        let json = try await get(.instagram, "me", ["fields": "user_id,username"], token: token)
        let id = (json["user_id"] as? String) ?? (json["user_id"] as? Int).map { String($0) } ?? (json["id"] as? String) ?? ""
        let account = MetaAccount(
            id: id,
            platform: .instagram,
            name: json["username"] as? String ?? id,
            token: token,
            host: .instagram,
            tokenRefreshedAt: .now
        )
        // Swap a fresh token for one that lasts 60 days and can be renewed.
        return (try? await refreshedIfNeeded(account, force: true)) ?? account
    }

    /// Instagram Login tokens last 60 days. Renew them once a week while they still work.
    static func refreshedIfNeeded(_ account: MetaAccount, force: Bool = false) async throws -> MetaAccount {
        guard account.host == .instagram else { return account }
        let last = account.tokenRefreshedAt ?? .distantPast
        guard force || last < .now.addingTimeInterval(-7 * 86400) else { return account }
        var components = URLComponents(string: "https://graph.instagram.com/refresh_access_token")!
        components.queryItems = [
            URLQueryItem(name: "grant_type", value: "ig_refresh_token"),
            URLQueryItem(name: "access_token", value: account.token),
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let token = json["access_token"] as? String else { return account }
        var updated = account
        updated.token = token
        updated.tokenRefreshedAt = .now
        return updated
    }

    // MARK: Reports

    static func report(for account: MetaAccount, now: Date = .now) async throws -> SocialReport {
        switch account.platform {
        case .instagram: return try await instagramReport(account, now: now)
        case .facebook: return try await facebookReport(account, now: now)
        }
    }

    private struct Periods {
        let since: Int
        let until: Int
        let prevSince: Int

        init(now: Date) {
            let end = Calendar(identifier: .gregorian).startOfDay(for: now)
            until = Int(end.timeIntervalSince1970)
            since = until - MetaAPI.periodDays * 86400
            prevSince = since - MetaAPI.periodDays * 86400
        }
    }

    private static func instagramReport(_ account: MetaAccount, now: Date) async throws -> SocialReport {
        let host = account.host
        // With Instagram Login the account is always "me".
        let node = host == .instagram ? "me" : account.id
        let token = account.token
        let name = account.displayName

        let profile = try await get(host, node, ["fields": "username,followers_count"], token: token, accountName: name)
        let periods = Periods(now: now)

        let wanted: [(key: String, label: String)] = [
            ("reach", "Reichweite"),
            ("views", "Aufrufe"),
            ("total_interactions", "Interaktionen"),
        ]
        var metrics: [SocialMetric] = []
        for metric in wanted {
            // One request per metric, so a metric Meta renamed does not hide the others.
            guard let value = try? await instagramTotal(host, node, metric.key, periods.since, periods.until, token) else { continue }
            let previous = try? await instagramTotal(host, node, metric.key, periods.prevSince, periods.since, token)
            metrics.append(SocialMetric(key: metric.key, label: metric.label, value: value, previous: previous))
        }

        let media = (try? await get(host, "\(node)/media", [
            "fields": "id,caption,timestamp,like_count,comments_count,permalink",
            "limit": String(postCount),
        ], token: token)) ?? [:]
        let posts: [SocialPost] = (media["data"] as? [[String: Any]] ?? []).compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return SocialPost(
                id: id,
                text: firstLine(item["caption"] as? String),
                date: parseDate(item["timestamp"] as? String),
                likes: item["like_count"] as? Int ?? 0,
                comments: item["comments_count"] as? Int ?? 0,
                permalink: item["permalink"] as? String
            )
        }

        return SocialReport(
            accountKey: account.key,
            platform: .instagram,
            name: profile["username"] as? String ?? account.name,
            fetchedAt: now,
            followers: profile["followers_count"] as? Int,
            metrics: metrics,
            posts: posts
        )
    }

    private static func instagramTotal(
        _ host: MetaHost, _ node: String, _ metric: String, _ since: Int, _ until: Int, _ token: String
    ) async throws -> Int {
        let json = try await get(host, "\(node)/insights", [
            "metric": metric,
            "period": "day",
            "metric_type": "total_value",
            "since": String(since),
            "until": String(until),
        ], token: token)
        guard let entry = (json["data"] as? [[String: Any]])?.first,
              let total = entry["total_value"] as? [String: Any],
              let value = total["value"] as? Int
        else { throw MetaError.api("Keine Daten für \(metric)") }
        return value
    }

    private static func facebookReport(_ account: MetaAccount, now: Date) async throws -> SocialReport {
        let token = account.token
        let page = try await get(.facebook, account.id, ["fields": "name,followers_count,fan_count"], token: token, accountName: account.name)
        let periods = Periods(now: now)

        // Meta renames Page metrics from time to time; the first name that works wins.
        let wanted: [(key: String, label: String, names: [String])] = [
            ("views", "Aufrufe", ["page_media_view", "page_impressions"]),
            ("page_post_engagements", "Interaktionen", ["page_post_engagements"]),
            ("page_daily_follows", "Neue Follower", ["page_daily_follows_unique", "page_follows"]),
        ]
        var metrics: [SocialMetric] = []
        for metric in wanted {
            for name in metric.names {
                guard let value = try? await pageSum(account.id, name, periods.since, periods.until, token) else { continue }
                let previous = try? await pageSum(account.id, name, periods.prevSince, periods.since, token)
                metrics.append(SocialMetric(key: metric.key, label: metric.label, value: value, previous: previous))
                break
            }
        }

        let feed = (try? await get(.facebook, "\(account.id)/published_posts", [
            "fields": "id,message,created_time,permalink_url,reactions.summary(total_count).limit(0),comments.summary(total_count).limit(0)",
            "limit": String(postCount),
        ], token: token)) ?? [:]
        let posts: [SocialPost] = (feed["data"] as? [[String: Any]] ?? []).compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return SocialPost(
                id: id,
                text: firstLine(item["message"] as? String),
                date: parseDate(item["created_time"] as? String),
                likes: summaryCount(item["reactions"]),
                comments: summaryCount(item["comments"]),
                permalink: item["permalink_url"] as? String
            )
        }

        return SocialReport(
            accountKey: account.key,
            platform: .facebook,
            name: page["name"] as? String ?? account.name,
            fetchedAt: now,
            followers: (page["followers_count"] as? Int) ?? (page["fan_count"] as? Int),
            metrics: metrics,
            posts: posts
        )
    }

    /// Sum of the daily values of a Page metric.
    private static func pageSum(_ pageID: String, _ metric: String, _ since: Int, _ until: Int, _ token: String) async throws -> Int {
        let json = try await get(.facebook, "\(pageID)/insights", [
            "metric": metric,
            "period": "day",
            "since": String(since),
            "until": String(until),
        ], token: token)
        guard let entry = (json["data"] as? [[String: Any]])?.first,
              let values = entry["values"] as? [[String: Any]]
        else { throw MetaError.api("Keine Daten für \(metric)") }
        return values.reduce(0) { $0 + (($1["value"] as? Int) ?? 0) }
    }

    // MARK: Helpers

    private static func summaryCount(_ value: Any?) -> Int {
        ((value as? [String: Any])?["summary"] as? [String: Any])?["total_count"] as? Int ?? 0
    }

    private static func firstLine(_ text: String?) -> String {
        let line = (text ?? "").split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.isEmpty ? "(ohne Text)" : line
    }

    private static func parseDate(_ string: String?) -> Date {
        guard let string else { return .distantPast }
        // Meta sends "2026-11-01T10:00:00+0000".
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter.date(from: string) ?? .distantPast
    }
}
