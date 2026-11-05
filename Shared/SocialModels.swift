import Foundation

enum SocialPlatform: String, Codable, Hashable {
    case instagram
    case facebook

    var shortName: String { self == .instagram ? "IG" : "FB" }
    var title: String { self == .instagram ? "Instagram" : "Facebook" }
}

/// Which Graph API host the token belongs to.
enum MetaHost: String, Codable, Hashable {
    /// graph.facebook.com: Page tokens, also for Instagram accounts linked to a Page.
    case facebook
    /// graph.instagram.com: tokens from "Instagram API with Instagram Login".
    case instagram
}

/// A Facebook Page or Instagram account the widgets can read.
struct MetaAccount: Codable, Hashable, Identifiable {
    var id: String
    var platform: SocialPlatform
    /// Page name or Instagram username.
    var name: String
    var token: String
    var host: MetaHost
    /// When an Instagram Login token was last renewed (they run for 60 days).
    var tokenRefreshedAt: Date?

    var displayName: String { platform == .instagram ? "@\(name)" : name }
    var key: String { "\(platform.rawValue).\(id)" }
}

struct SocialMetric: Codable, Hashable, Identifiable {
    var id: String { key }
    var key: String
    var label: String
    var value: Int
    var previous: Int?

    var changePercent: Double? {
        guard let previous, previous > 0 else { return nil }
        return Double(value - previous) / Double(previous) * 100
    }
}

struct SocialPost: Codable, Hashable, Identifiable {
    var id: String
    var text: String
    var date: Date
    /// Likes on Instagram, reactions on Facebook.
    var likes: Int
    var comments: Int
    var permalink: String?
}

struct SocialReport: Codable, Hashable, Identifiable {
    var id: String { accountKey }
    var accountKey: String
    var platform: SocialPlatform
    var name: String
    var fetchedAt: Date
    var followers: Int?
    /// Change against the oldest stored count of the last 28 days.
    var followersChange: Int?
    var followersSince: Date?
    var metrics: [SocialMetric]
    var posts: [SocialPost]

    var displayName: String { platform == .instagram ? "@\(name)" : name }

    func metric(_ key: String) -> SocialMetric? { metrics.first { $0.key == key } }
}

extension SocialReport {
    static let sampleInstagram = SocialReport(
        accountKey: "instagram.1",
        platform: .instagram,
        name: "beispiel",
        fetchedAt: .now,
        followers: 2480,
        followersChange: 36,
        followersSince: .now.addingTimeInterval(-28 * 86400),
        metrics: [
            SocialMetric(key: "reach", label: "Reichweite", value: 18400, previous: 15200),
            SocialMetric(key: "views", label: "Aufrufe", value: 52100, previous: 47900),
            SocialMetric(key: "total_interactions", label: "Interaktionen", value: 1320, previous: 1410),
        ],
        posts: [
            SocialPost(id: "1", text: "Neuer Beitrag mit einem längeren Text", date: .now.addingTimeInterval(-2 * 86400), likes: 184, comments: 12),
            SocialPost(id: "2", text: "Hinter den Kulissen", date: .now.addingTimeInterval(-6 * 86400), likes: 131, comments: 4),
            SocialPost(id: "3", text: "Produktvorstellung", date: .now.addingTimeInterval(-11 * 86400), likes: 98, comments: 7),
        ]
    )

    static let sampleFacebook = SocialReport(
        accountKey: "facebook.2",
        platform: .facebook,
        name: "Beispiel GmbH",
        fetchedAt: .now,
        followers: 1215,
        followersChange: -3,
        followersSince: .now.addingTimeInterval(-28 * 86400),
        metrics: [
            SocialMetric(key: "views", label: "Aufrufe", value: 8400, previous: 9100),
            SocialMetric(key: "page_post_engagements", label: "Interaktionen", value: 410, previous: 350),
        ],
        posts: [
            SocialPost(id: "4", text: "Wir sind auf der Messe", date: .now.addingTimeInterval(-3 * 86400), likes: 42, comments: 5),
        ]
    )
}
