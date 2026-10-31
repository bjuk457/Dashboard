import SwiftUI

@main
struct SearchConsoleDashboardApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Search Console") {
            ContentView()
                .environment(model)
                .frame(minWidth: 520, minHeight: 420)
        }
        .windowResizability(.contentMinSize)
    }
}
