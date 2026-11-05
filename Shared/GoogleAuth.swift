import CryptoKit
import Foundation

/// OAuth for an installed app (Google "iOS" client type) with PKCE, no client secret.
enum GoogleAuth {
    static let scope = "https://www.googleapis.com/auth/webmasters.readonly"
    private static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

    static var clientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String ?? ""
    }

    /// "123-abc.apps.googleusercontent.com" becomes "com.googleusercontent.apps.123-abc".
    static var callbackScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    static var redirectURI: String { "\(callbackScheme):/oauth2redirect" }

    struct PKCE {
        let verifier: String
        let challenge: String

        init() {
            var bytes = [UInt8](repeating: 0, count: 32)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            verifier = Data(bytes).base64URLEncoded
            challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        }
    }

    static func authorizationURL(pkce: PKCE, state: String) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: pkce.challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        return components.url!
    }

    private struct TokenResponse: Decodable {
        var access_token: String
        var expires_in: Double
        var refresh_token: String?
    }

    private static func requestToken(_ fields: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        request.httpBody = fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 400 || status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else {
            throw APIError.http(status, String(decoding: data, as: UTF8.self))
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    /// Trade the code from the sign-in redirect for tokens.
    static func exchange(code: String, pkce: PKCE) async throws -> TokenSet {
        let response = try await requestToken([
            "client_id": clientID,
            "code": code,
            "code_verifier": pkce.verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
        guard let refresh = response.refresh_token else { throw APIError.unauthorized }
        return TokenSet(
            accessToken: response.access_token,
            refreshToken: refresh,
            expiresAt: .now.addingTimeInterval(response.expires_in)
        )
    }

    /// A usable access token, refreshed and stored when the old one expired.
    static func validAccessToken() async throws -> String {
        guard var token = SharedStore.token else { throw APIError.notSignedIn }
        if token.expiresAt > .now.addingTimeInterval(60) { return token.accessToken }

        let response = try await requestToken([
            "client_id": clientID,
            "grant_type": "refresh_token",
            "refresh_token": token.refreshToken,
        ])
        token.accessToken = response.access_token
        token.expiresAt = .now.addingTimeInterval(response.expires_in)
        if let refresh = response.refresh_token { token.refreshToken = refresh }
        SharedStore.token = token
        return token.accessToken
    }

    /// Fetch a fresh report, falling back to the last stored one on failure.
    static func loadReport(for site: String) async -> (SiteReport?, Error?) {
        do {
            let report = try await SearchConsoleAPI(accessToken: validAccessToken()).report(site: site)
            SharedStore.save(report: report)
            return (report, nil)
        } catch {
            return (SharedStore.report(for: site), error)
        }
    }
}

extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
