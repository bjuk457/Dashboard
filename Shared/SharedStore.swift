import Foundation

struct TokenSet: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
}

/// Storage shared between the app and the widget through the App Group.
enum SharedStore {
    static var groupID: String {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? ""
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T?, _ key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    static var token: TokenSet? {
        get { load("token") }
        set { save(newValue, "token") }
    }

    /// All properties the Google account can read.
    static var sites: [String] {
        get { load("sites") ?? [] }
        set { save(newValue, "sites") }
    }

    static func report(for site: String) -> SiteReport? {
        load("report.\(site)")
    }

    static func save(report: SiteReport) {
        save(report, "report.\(report.siteURL)")
    }

    static func signOut() {
        token = nil
        for site in sites { defaults.removeObject(forKey: "report.\(site)") }
        sites = []
    }
}
