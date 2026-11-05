import SwiftUI

@main
struct SearchConsoleDashboardApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Dashboard") {
            ContentView()
                .environment(model)
                .frame(minWidth: 520, minHeight: 420)
        }
        .windowResizability(.contentMinSize)

        Settings {
            MetaSettingsView()
                .environment(model)
        }
    }
}
