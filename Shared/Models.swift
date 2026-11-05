import Foundation

struct Totals: Codable, Hashable {
    var clicks: Int
    var impressions: Int
    /// Click-through rate in percent.
    var ctr: Double
    var position: Double

    static let zero = Totals(clicks: 0, impressions: 0, ctr: 0, position: 0)
}

struct QueryStat: Codable, Hashable, Identifiable {
    var id: String { query }
    var query: String
    var clicks: Int
    var impressions: Int
    var ctr: Double
    var position: Double?
    var clicksChange: Int
    /// Positive means the query moved up in the results.
    var positionChange: Double?
}

struct SiteReport: Codable, Hashable {
    var siteURL: String
    var startDate: Date
    var endDate: Date
    var fetchedAt: Date
    var totals: Totals
    var previous: Totals
    var topQueries: [QueryStat]
    var winners: [QueryStat]
    var losers: [QueryStat]

    var host: String { displayName(for: siteURL) }

    var clicksChangePercent: Double? {
        previous.clicks == 0
            ? nil
            : Double(totals.clicks - previous.clicks) / Double(previous.clicks) * 100
    }

    var positionChange: Double {
        // Lower is better, so a drop in position is an improvement.
        previous.position - totals.position
    }
}

func displayName(for site: String) -> String {
    if site.hasPrefix("sc-domain:") {
        return String(site.dropFirst("sc-domain:".count))
    }
    let host = URL(string: site)?.host() ?? site
    return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
}

extension SiteReport {
    static let sample = SiteReport(
        siteURL: "https://www.example.com/",
        startDate: .now.addingTimeInterval(-31 * 86400),
        endDate: .now.addingTimeInterval(-3 * 86400),
        fetchedAt: .now,
        totals: Totals(clicks: 1240, impressions: 48200, ctr: 2.6, position: 14.2),
        previous: Totals(clicks: 1100, impressions: 45100, ctr: 2.4, position: 15.0),
        topQueries: [
            QueryStat(query: "beispiel suchbegriff", clicks: 210, impressions: 3100, ctr: 6.8, position: 3.1, clicksChange: 25, positionChange: 0.4),
            QueryStat(query: "zweiter begriff", clicks: 120, impressions: 2500, ctr: 4.8, position: 5.6, clicksChange: -8, positionChange: -0.9),
            QueryStat(query: "dritter begriff", clicks: 95, impressions: 1900, ctr: 5.0, position: 4.2, clicksChange: 12, positionChange: 1.2),
            QueryStat(query: "vierter begriff", clicks: 60, impressions: 1400, ctr: 4.3, position: 7.9, clicksChange: 0, positionChange: nil),
            QueryStat(query: "fünfter begriff", clicks: 41, impressions: 900, ctr: 4.6, position: 6.3, clicksChange: 5, positionChange: 0.2),
        ],
        winners: [
            QueryStat(query: "beispiel suchbegriff", clicks: 210, impressions: 3100, ctr: 6.8, position: 3.1, clicksChange: 25, positionChange: 0.4),
        ],
        losers: [
            QueryStat(query: "zweiter begriff", clicks: 120, impressions: 2500, ctr: 4.8, position: 5.6, clicksChange: -8, positionChange: -0.9),
        ]
    )
}
