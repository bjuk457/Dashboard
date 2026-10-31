import AuthenticationServices
import Observation
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class AppModel {
    var signedIn = SharedStore.token != nil
    var reports: [SiteReport] = SharedStore.sites.compactMap(SharedStore.report(for:))
    var isLoading = false
    var errorMessage: String?

    func signIn(using session: WebAuthenticationSession) async {
        guard !GoogleAuth.clientID.isEmpty else {
            errorMessage = "Es ist keine Google-Client-ID eingetragen (Config/Config.xcconfig)."
            return
        }
        let pkce = GoogleAuth.PKCE()
        let state = UUID().uuidString
        do {
            let callback = try await session.authenticate(
                using: GoogleAuth.authorizationURL(pkce: pkce, state: state),
                callbackURLScheme: GoogleAuth.callbackScheme,
                preferredBrowserSession: .shared
            )
            let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard items.first(where: { $0.name == "state" })?.value == state,
                  let code = items.first(where: { $0.name == "code" })?.value
            else {
                errorMessage = "Die Anmeldung bei Google wurde nicht abgeschlossen."
                return
            }
            SharedStore.token = try await GoogleAuth.exchange(code: code, pkce: pkce)
            signedIn = true
            errorMessage = nil
            await refresh()
        } catch ASWebAuthenticationSessionError.canceledLogin {
            // The user closed the sign-in window.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let sites = try await SearchConsoleAPI(accessToken: GoogleAuth.validAccessToken()).listSites()
            SharedStore.sites = sites
            var loaded: [SiteReport] = []
            for site in sites {
                let (report, error) = await GoogleAuth.loadReport(for: site)
                if let report { loaded.append(report) }
                if let error { errorMessage = error.localizedDescription }
            }
            reports = loaded
            WidgetCenter.shared.reloadAllTimelines()
        } catch APIError.unauthorized {
            errorMessage = APIError.unauthorized.localizedDescription
            signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        SharedStore.signOut()
        signedIn = false
        reports = []
        WidgetCenter.shared.reloadAllTimelines()
    }
}
