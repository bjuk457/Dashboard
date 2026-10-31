import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case notSignedIn
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Google hat die Anmeldung abgelehnt. Bitte in der App neu anmelden."
        case .notSignedIn: return "Bitte in der App mit Google anmelden."
        case let .http(code, body): return "Fehler \(code): \(body.prefix(200))"
        }
    }
}

/// Minimal client for the Search Console API.
struct SearchConsoleAPI {
    let accessToken: String

    static let periodDays = 28
    /// Google finalizes the figures with a delay of roughly two to three days.
    static let delayDays = 3
    static let topQueries = 25
    static let movers = 5

    private static let base = "https://www.googleapis.com/webmasters/v3"

    struct Row: Decodable {
        var keys: [String]?
        var clicks: Double
        var impressions: Double
        var ctr: Double
        var position: Double
    }

    private struct QueryResponse: Decodable { var rows: [Row]? }

    private struct SitesResponse: Decodable {
        struct Entry: Decodable {
            var siteUrl: String
            var permissionLevel: String
        }
        var siteEntry: [Entry]?
    }

    private func send(_ request: URLRequest) async throws -> Data {
        var request = request
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else {
            throw APIError.http(status, String(decoding: data, as: UTF8.self))
        }
        return data
    }

    func listSites() async throws -> [String] {
        let data = try await send(URLRequest(url: URL(string: "\(Self.base)/sites")!))
        let response = try JSONDecoder().decode(SitesResponse.self, from: data)
        return (response.siteEntry ?? [])
            .filter { $0.permissionLevel != "siteUnverifiedUser" }
            .map(\.siteUrl)
            .sorted()
    }

    func query(
        site: String,
        start: String,
        end: String,
        dimensions: [String] = [],
        rowLimit: Int = 1000
    ) async throws -> [Row] {
        let encoded = site.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? site
        var request = URLRequest(url: URL(string: "\(Self.base)/sites/\(encoded)/searchAnalytics/query")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["startDate": start, "endDate": end, "rowLimit": rowLimit]
        if !dimensions.isEmpty { body["dimensions"] = dimensions }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(request)
        return try JSONDecoder().decode(QueryResponse.self, from: data).rows ?? []
    }

    /// The last 28 days with data compared with the 28 days before.
    func report(site: String, now: Date = .now) async throws -> SiteReport {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: -Self.delayDays, to: today)!
        let start = calendar.date(byAdding: .day, value: -(Self.periodDays - 1), to: end)!
        let prevEnd = calendar.date(byAdding: .day, value: -1, to: start)!
        let prevStart = calendar.date(byAdding: .day, value: -(Self.periodDays - 1), to: prevEnd)!

        let f = Self.dayFormatter
        let (s, e, ps, pe) = (f.string(from: start), f.string(from: end), f.string(from: prevStart), f.string(from: prevEnd))

        async let totals = query(site: site, start: s, end: e)
        async let prevTotals = query(site: site, start: ps, end: pe)
        async let queries = query(site: site, start: s, end: e, dimensions: ["query"])
        async let prevQueries = query(site: site, start: ps, end: pe, dimensions: ["query"])

        let current = try await Self.byQuery(queries)
        let previous = try await Self.byQuery(prevQueries)
        let currentOrder = try await queries.compactMap { $0.keys?.first }

        var entries: [String: QueryStat] = [:]
        for query in Set(current.keys).union(previous.keys) {
            entries[query] = Self.stat(query, current[query], previous[query])
        }

        let top = currentOrder.compactMap { entries[$0] }
            .sorted { ($0.clicks, $0.impressions) > ($1.clicks, $1.impressions) }
            .prefix(Self.topQueries)
        let byChange = entries.values.sorted { $0.clicksChange < $1.clicksChange }

        return SiteReport(
            siteURL: site,
            startDate: start,
            endDate: end,
            fetchedAt: now,
            totals: try await Self.totals(totals),
            previous: try await Self.totals(prevTotals),
            topQueries: Array(top),
            winners: Array(byChange.reversed().filter { $0.clicksChange > 0 }.prefix(Self.movers)),
            losers: Array(byChange.filter { $0.clicksChange < 0 }.prefix(Self.movers))
        )
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func byQuery(_ rows: [Row]) -> [String: Row] {
        var result: [String: Row] = [:]
        for row in rows {
            if let key = row.keys?.first { result[key] = row }
        }
        return result
    }

    private static func totals(_ rows: [Row]) -> Totals {
        guard let row = rows.first else { return .zero }
        return Totals(
            clicks: Int(row.clicks),
            impressions: Int(row.impressions),
            ctr: (row.ctr * 10000).rounded() / 100,
            position: (row.position * 10).rounded() / 10
        )
    }

    private static func stat(_ query: String, _ current: Row?, _ previous: Row?) -> QueryStat {
        let position = current.map { ($0.position * 10).rounded() / 10 }
        let positionChange: Double? = {
            guard let current, let previous else { return nil }
            return ((previous.position - current.position) * 10).rounded() / 10
        }()
        return QueryStat(
            query: query,
            clicks: Int(current?.clicks ?? 0),
            impressions: Int(current?.impressions ?? 0),
            ctr: ((current?.ctr ?? 0) * 1000).rounded() / 10,
            position: position,
            clicksChange: Int(current?.clicks ?? 0) - Int(previous?.clicks ?? 0),
            positionChange: positionChange
        )
    }
}
