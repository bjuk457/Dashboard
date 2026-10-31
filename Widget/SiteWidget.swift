import SwiftUI
import WidgetKit

struct SiteEntry: TimelineEntry {
    let date: Date
    let report: SiteReport?
    let message: String?
}

struct SiteProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SiteEntry {
        SiteEntry(date: .now, report: .sample, message: nil)
    }

    func snapshot(for configuration: SelectSiteIntent, in context: Context) async -> SiteEntry {
        context.isPreview ? placeholder(in: context) : await entry(for: configuration)
    }

    func timeline(for configuration: SelectSiteIntent, in context: Context) async -> Timeline<SiteEntry> {
        let entry = await entry(for: configuration)
        // Google updates the figures about once a day, so a few hours is plenty.
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3 * 3600)))
    }

    private func entry(for configuration: SelectSiteIntent) async -> SiteEntry {
        guard let site = configuration.site?.id ?? SharedStore.sites.first else {
            return SiteEntry(date: .now, report: nil, message: "Bitte in der App „Search Console“ mit Google anmelden.")
        }
        let (report, error) = await GoogleAuth.loadReport(for: site)
        return SiteEntry(date: .now, report: report, message: report == nil ? error?.localizedDescription : nil)
    }
}

struct SiteWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SiteWidget", intent: SelectSiteIntent.self, provider: SiteProvider()) { entry in
            SiteWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Website")
        .description("Klicks, Position und die wichtigsten Suchbegriffe einer Website.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct SiteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SiteEntry

    var body: some View {
        if let report = entry.report {
            switch family {
            case .systemSmall: small(report)
            case .systemMedium: medium(report)
            default: large(report)
            }
        } else {
            Text(entry.message ?? "Keine Daten")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func header(_ report: SiteReport) -> some View {
        HStack {
            Text(report.host).font(.caption.weight(.semibold)).lineLimit(1)
            Spacer()
            Text("\(Fmt.day(report.startDate)) – \(Fmt.day(report.endDate))")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func clicks(_ report: SiteReport) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Fmt.number(report.totals.clicks))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
            HStack(spacing: 4) {
                Text("Klicks").font(.caption2).foregroundStyle(.secondary)
                ChangeLabel(
                    text: Fmt.signedPercent(report.clicksChangePercent),
                    good: report.clicksChangePercent.map { $0 >= 0 }
                )
            }
        }
    }

    private func stats(_ report: SiteReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            stat("Impressionen", Fmt.compact(report.totals.impressions))
            stat("CTR", Fmt.decimal(report.totals.ctr) + " %")
            HStack(spacing: 4) {
                stat("Ø Position", Fmt.decimal(report.totals.position))
                ChangeLabel(
                    text: (report.positionChange >= 0 ? "▲ " : "▼ ") + Fmt.decimal(abs(report.positionChange)),
                    good: report.positionChange >= 0
                )
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.medium))
        }
    }

    private func queryList(_ queries: [QueryStat], limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(queries.prefix(limit)) { q in
                HStack(spacing: 6) {
                    Text(q.query).font(.caption).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Fmt.number(q.clicks)).font(.caption.monospacedDigit())
                    ChangeLabel(text: Fmt.signed(q.clicksChange), good: q.clicksChange == 0 ? nil : q.clicksChange > 0)
                        .frame(width: 34, alignment: .trailing)
                    Text(q.position.map(Fmt.decimal) ?? "–")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }

    private func small(_ report: SiteReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(report.host).font(.caption.weight(.semibold)).lineLimit(1)
            clicks(report)
            Spacer(minLength: 0)
            if let top = report.topQueries.first {
                Text(top.query).font(.caption2).lineLimit(1).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medium(_ report: SiteReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(report)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    clicks(report)
                    stats(report)
                }
                .frame(width: 120, alignment: .leading)
                queryList(report.topQueries, limit: 5)
            }
            Spacer(minLength: 0)
        }
    }

    private func large(_ report: SiteReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(report)
            HStack(alignment: .top) {
                clicks(report)
                Spacer()
                stats(report)
            }
            Divider()
            Text("Top-Suchbegriffe").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            queryList(report.topQueries, limit: 8)
            if !report.winners.isEmpty || !report.losers.isEmpty {
                Divider()
                HStack(alignment: .top, spacing: 12) {
                    movers("Gewinner", report.winners)
                    movers("Verlierer", report.losers)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func movers(_ title: String, _ queries: [QueryStat]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(queries.prefix(3)) { q in
                HStack(spacing: 4) {
                    Text(q.query).font(.caption2).lineLimit(1)
                    Spacer(minLength: 2)
                    ChangeLabel(text: Fmt.signed(q.clicksChange), good: q.clicksChange > 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
