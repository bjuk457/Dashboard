import SwiftUI
import WidgetKit

struct SocialEntry: TimelineEntry {
    let date: Date
    let site: String?
    let reports: [SocialReport]
    let message: String?
}

struct SocialProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SocialEntry {
        SocialEntry(date: .now, site: SiteReport.sample.siteURL, reports: [.sampleInstagram, .sampleFacebook], message: nil)
    }

    func snapshot(for configuration: SelectSiteIntent, in context: Context) async -> SocialEntry {
        context.isPreview ? placeholder(in: context) : await entry(for: configuration)
    }

    func timeline(for configuration: SelectSiteIntent, in context: Context) async -> Timeline<SocialEntry> {
        let entry = await entry(for: configuration)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3 * 3600)))
    }

    private func entry(for configuration: SelectSiteIntent) async -> SocialEntry {
        guard let site = configuration.site?.id ?? SharedStore.sites.first else {
            return SocialEntry(date: .now, site: nil, reports: [], message: "Bitte in der App „Dashboard“ anmelden.")
        }
        guard !SharedStore.accounts(for: site).isEmpty else {
            return SocialEntry(date: .now, site: site, reports: [], message: "Für \(displayName(for: site)) ist kein Instagram- oder Facebook-Konto zugeordnet.")
        }
        let (reports, error) = await SharedStore.loadSocial(for: site)
        return SocialEntry(date: .now, site: site, reports: reports, message: reports.isEmpty ? error?.localizedDescription : nil)
    }
}

struct SocialWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SocialWidget", intent: SelectSiteIntent.self, provider: SocialProvider()) { entry in
            SocialWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Social Media")
        .description("Follower, Reichweite und letzte Beiträge auf Instagram und Facebook.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SocialWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SocialEntry

    var body: some View {
        if entry.reports.isEmpty {
            Text(entry.message ?? "Keine Daten")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.site.map(displayName(for:)) ?? "Social Media")
                        .font(.caption.weight(.semibold)).lineLimit(1)
                    Spacer()
                    if family != .systemSmall {
                        Text("letzte 28 Tage").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                switch family {
                case .systemSmall:
                    ForEach(entry.reports) { report in
                        VStack(alignment: .leading, spacing: 1) {
                            FollowersLine(report: report)
                            if let reach = report.metric("reach") ?? report.metric("views") {
                                Text("\(reach.label) \(Fmt.compact(reach.value))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                case .systemMedium:
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(entry.reports.prefix(2)) { SocialCard(report: $0) }
                    }
                default:
                    ForEach(entry.reports.prefix(2)) { report in
                        SocialCard(report: report, postLimit: entry.reports.count > 1 ? 2 : 3)
                        if report.id != entry.reports.prefix(2).last?.id { Divider() }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
