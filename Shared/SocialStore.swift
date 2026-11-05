import Foundation

/// Meta accounts, their assignment to websites and the last loaded figures.
extension SharedStore {
    static var metaAccounts: [MetaAccount] {
        get { load("meta.accounts") ?? [] }
        set { save(newValue, "meta.accounts") }
    }

    /// Search Console site URL → account keys shown with that site.
    static var socialAssignments: [String: [String]] {
        get { load("meta.assignments") ?? [:] }
        set { save(newValue, "meta.assignments") }
    }

    static func accounts(for site: String) -> [MetaAccount] {
        let keys = socialAssignments[site] ?? []
        return metaAccounts
            .filter { keys.contains($0.key) }
            // Instagram first, it is the main channel for all sites.
            .sorted { ($0.platform == .instagram ? 0 : 1) < ($1.platform == .instagram ? 0 : 1) }
    }

    static func socialReport(for key: String) -> SocialReport? {
        load("social.\(key)")
    }

    static func save(social report: SocialReport) {
        save(report, "social.\(report.accountKey)")
    }

    static func update(account: MetaAccount) {
        var accounts = metaAccounts
        if let index = accounts.firstIndex(where: { $0.key == account.key }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        metaAccounts = accounts
    }

    static func remove(account: MetaAccount) {
        metaAccounts.removeAll { $0.key == account.key }
        var assignments = socialAssignments
        for site in assignments.keys { assignments[site]?.removeAll { $0 == account.key } }
        socialAssignments = assignments
        defaults.removeObject(forKey: "social.\(account.key)")
        defaults.removeObject(forKey: "followers.\(account.key)")
    }

    // MARK: Follower history

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Store today's follower count and return the change against the oldest
    /// count of the last 28 days. Meta has no history of follower totals, so it is kept here.
    static func recordFollowers(_ count: Int, for key: String, now: Date = .now) -> (change: Int, since: Date)? {
        var history: [String: Int] = load("followers.\(key)") ?? [:]
        let today = dayFormatter.string(from: now)
        history[today] = count
        let cutoff = dayFormatter.string(from: now.addingTimeInterval(-Double(MetaAPI.periodDays) * 86400))
        // Keep 60 days so the comparison still works after a gap.
        let keep = dayFormatter.string(from: now.addingTimeInterval(-60 * 86400))
        history = history.filter { $0.key >= keep }
        save(history, "followers.\(key)")

        let candidates = history.keys.filter { $0 < today }.sorted()
        guard let base = candidates.first(where: { $0 >= cutoff }) ?? candidates.last,
              let baseCount = history[base],
              let date = dayFormatter.date(from: base)
        else { return nil }
        return (count - baseCount, date)
    }

    // MARK: Loading

    /// Fresh figures for every account shown with a site, falling back to the last stored ones.
    static func loadSocial(for site: String) async -> ([SocialReport], Error?) {
        var reports: [SocialReport] = []
        var lastError: Error?
        for account in accounts(for: site) {
            do {
                reports.append(try await loadSocial(account: account))
            } catch {
                lastError = error
                if let cached = socialReport(for: account.key) { reports.append(cached) }
            }
        }
        return (reports, lastError)
    }

    static func loadSocial(account: MetaAccount) async throws -> SocialReport {
        let current = try await MetaAPI.refreshedIfNeeded(account)
        if current != account { update(account: current) }
        var report = try await MetaAPI.report(for: current)
        if let followers = report.followers,
           let change = recordFollowers(followers, for: account.key) {
            report.followersChange = change.change
            report.followersSince = change.since
        }
        save(social: report)
        return report
    }

    /// Guess which accounts belong to which site from their names.
    static func suggestAssignments(sites: [String], accounts: [MetaAccount]) -> [String: [String]] {
        // Accounts whose names do not resemble the domain.
        let hints: [String: [String]] = [
            "3dprotec.com": ["printhive"],
        ]
        func normalized(_ text: String) -> String {
            text.lowercased().filter { $0.isLetter || $0.isNumber }
        }
        var result = socialAssignments
        for site in sites {
            let host = displayName(for: site)
            let stem = normalized(String(host.split(separator: ".").first ?? ""))
            let words = [stem] + (hints[host] ?? []).map(normalized)
            let matches = accounts.filter { account in
                let name = normalized(account.name)
                return !name.isEmpty && words.contains { !$0.isEmpty && (name.contains($0) || $0.contains(name)) }
            }
            if result[site, default: []].isEmpty, !matches.isEmpty {
                result[site] = matches.map(\.key)
            }
        }
        return result
    }
}
