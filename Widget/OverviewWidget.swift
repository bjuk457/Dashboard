import SwiftUI
import WidgetKit

struct OverviewEntry: TimelineEntry {
    let date: Date
    let reports: [SiteReport]
    var social: [String: [SocialReport]] = [:]
    let message: String?
}

struct OverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> OverviewEntry {
        OverviewEntry(
            date: .now,
            reports: [.sample],
            social: [SiteReport.sample.siteURL: [.sampleInstagram, .sampleFacebook]],
            message: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (OverviewEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task { completion(await load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OverviewEntry>) -> Void) {
        Task {
            let entry = await load()
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3 * 3600))))
        }
    }

    private func load() async -> OverviewEntry {
        let sites = SharedStore.sites
        guard !sites.isEmpty else {
            return OverviewEntry(date: .now, reports: [], message: "Bitte in der App „Dashboard“ mit Google anmelden.")
        }
        var reports: [SiteReport] = []
        var social: [String: [SocialReport]] = [:]
        var lastError: Error?
        for site in sites.prefix(6) {
            let (report, error) = await GoogleAuth.loadReport(for: site)
            if let report { reports.append(report) }
            if let error { lastError = error }
            social[site] = await SharedStore.loadSocial(for: site).0
        }
        return OverviewEntry(
            date: .now,
            reports: reports,
            social: social,
            message: reports.isEmpty ? lastError?.localizedDescription : nil
        )
    }
}

struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "OverviewWidget", provider: OverviewProvider()) { entry in
            OverviewWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Alle Websites")
        .description("Klicks, Position und Follower aller Websites auf einen Blick.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct OverviewWidgetView: View {
    let entry: OverviewEntry

    var body: some View {
        if entry.reports.isEmpty {
            Text(entry.message ?? "Keine Daten").font(.caption).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Websites").font(.caption.weight(.semibold))
                    Spacer()
                    if let first = entry.reports.first {
                        Text("\(Fmt.day(first.startDate)) – \(Fmt.day(first.endDate))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                ForEach(entry.reports, id: \.siteURL) { report in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(report.host).font(.caption).lineLimit(1)
                            HStack(spacing: 8) {
                                ForEach(entry.social[report.siteURL] ?? []) { FollowersLine(report: $0) }
                            }
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(Fmt.number(report.totals.clicks)).font(.callout.weight(.semibold).monospacedDigit())
                            ChangeLabel(
                                text: Fmt.signedPercent(report.clicksChangePercent),
                                good: report.clicksChangePercent.map { $0 >= 0 }
                            )
                        }
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("Ø " + Fmt.decimal(report.totals.position)).font(.caption.monospacedDigit())
                            ChangeLabel(
                                text: (report.positionChange >= 0 ? "▲ " : "▼ ") + Fmt.decimal(abs(report.positionChange)),
                                good: report.positionChange >= 0
                            )
                        }
                        .frame(width: 54, alignment: .trailing)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
