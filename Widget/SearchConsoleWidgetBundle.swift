import SwiftUI
import WidgetKit

@main
struct SearchConsoleWidgetBundle: WidgetBundle {
    var body: some Widget {
        OverviewWidget()
        SiteWidget()
        SocialWidget()
    }
}
