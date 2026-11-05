import AuthenticationServices
import Observation
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class AppModel {
    var signedIn = SharedStore.token != nil
    var reports: [SiteReport] = SharedStore.sites.compactMap(SharedStore.report(for:))
    var sites: [String] = SharedStore.sites
    var metaAccounts: [MetaAccount] = SharedStore.metaAccounts
    var assignments: [String: [String]] = SharedStore.socialAssignments
    var social: [String: SocialReport] = Dictionary(
        uniqueKeysWithValues: SharedStore.metaAccounts.compactMap { account in
            SharedStore.socialReport(for: account.key).map { (account.key, $0) }
        }
    )
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
            self.sites = sites
            var loaded: [SiteReport] = []
            for site in sites {
                let (report, error) = await GoogleAuth.loadReport(for: site)
                if let report { loaded.append(report) }
                if let error { errorMessage = error.localizedDescription }
            }
            reports = loaded
        } catch APIError.unauthorized {
            errorMessage = APIError.unauthorized.localizedDescription
            signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshSocial()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Meta

    func refreshSocial() async {
        for account in SharedStore.metaAccounts {
            do {
                social[account.key] = try await SharedStore.loadSocial(account: account)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        metaAccounts = SharedStore.metaAccounts
    }

    /// Load all Pages and linked Instagram accounts a Meta token can read.
    func connectMeta(token: String) async {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let found = try await MetaAPI.discoverAccounts(userToken: token)
            guard !found.isEmpty else {
                errorMessage = "Mit diesem Schlüssel ist keine Facebook-Seite erreichbar. Fehlt die Berechtigung pages_show_list?"
                return
            }
            add(found)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Add an Instagram account through an Instagram Login token.
    func connectInstagram(token: String) async {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            add([try await MetaAPI.instagramLoginAccount(token: token)])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func add(_ accounts: [MetaAccount]) {
        for account in accounts { SharedStore.update(account: account) }
        metaAccounts = SharedStore.metaAccounts
        SharedStore.socialAssignments = SharedStore.suggestAssignments(sites: sites, accounts: metaAccounts)
        assignments = SharedStore.socialAssignments
        errorMessage = nil
        Task {
            await refreshSocial()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func remove(_ account: MetaAccount) {
        SharedStore.remove(account: account)
        metaAccounts = SharedStore.metaAccounts
        assignments = SharedStore.socialAssignments
        social[account.key] = nil
        WidgetCenter.shared.reloadAllTimelines()
    }

    func isAssigned(_ account: MetaAccount, to site: String) -> Bool {
        assignments[site, default: []].contains(account.key)
    }

    func setAssigned(_ assigned: Bool, account: MetaAccount, site: String) {
        var list = assignments[site, default: []]
        list.removeAll { $0 == account.key }
        if assigned { list.append(account.key) }
        assignments[site] = list
        SharedStore.socialAssignments = assignments
        WidgetCenter.shared.reloadAllTimelines()
    }

    func socialReports(for site: String) -> [SocialReport] {
        let keys = assignments[site, default: []]
        return metaAccounts.filter { keys.contains($0.key) }.compactMap { social[$0.key] }
    }

    func signOut() {
        SharedStore.signOut()
        signedIn = false
        reports = []
        WidgetCenter.shared.reloadAllTimelines()
    }
}
