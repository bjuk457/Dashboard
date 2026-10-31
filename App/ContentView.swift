import AuthenticationServices
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession

    var body: some View {
        Group {
            if model.signedIn {
                reportList
            } else {
                signInView
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let message = model.errorMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .task {
            if model.signedIn { await model.refresh() }
        }
    }

    private var signInView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("Search Console").font(.title.bold())
            Text("Melde dich mit dem Google-Konto an, das Zugriff auf deine Websites in der Search Console hat. Danach kannst du die Widgets über „Widgets bearbeiten“ auf den Schreibtisch legen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 380)
            Button("Mit Google anmelden") {
                Task { await model.signIn(using: webAuthenticationSession) }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reportList: some View {
        List {
            ForEach(model.reports, id: \.siteURL) { report in
                Section {
                    SiteReportView(report: report)
                } header: {
                    Text(report.host)
                }
            }
        }
        .overlay {
            if model.reports.isEmpty && model.isLoading { ProgressView() }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                Button("Abmelden") { model.signOut() }
            }
        }
    }
}

struct SiteReportView: View {
    let report: SiteReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 24) {
                metric("Klicks", Fmt.number(report.totals.clicks), Fmt.signedPercent(report.clicksChangePercent), report.clicksChangePercent.map { $0 >= 0 })
                metric("Impressionen", Fmt.number(report.totals.impressions), nil, nil)
                metric("CTR", Fmt.decimal(report.totals.ctr) + " %", nil, nil)
                metric(
                    "Ø Position",
                    Fmt.decimal(report.totals.position),
                    (report.positionChange >= 0 ? "▲ " : "▼ ") + Fmt.decimal(abs(report.positionChange)),
                    report.positionChange >= 0
                )
            }
            Text("\(Fmt.day(report.startDate)) – \(Fmt.day(report.endDate)) im Vergleich zu den 28 Tagen davor")
                .font(.caption).foregroundStyle(.secondary)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Suchbegriff"); Text("Klicks"); Text("±"); Text("Impr."); Text("Pos.")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                ForEach(report.topQueries.prefix(10)) { q in
                    GridRow {
                        Text(q.query).lineLimit(1)
                        Text(Fmt.number(q.clicks)).monospacedDigit()
                        ChangeLabel(text: Fmt.signed(q.clicksChange), good: q.clicksChange == 0 ? nil : q.clicksChange > 0)
                        Text(Fmt.number(q.impressions)).monospacedDigit()
                        Text(q.position.map(Fmt.decimal) ?? "–").monospacedDigit()
                    }
                    .font(.callout)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func metric(_ title: String, _ value: String, _ change: String?, _ good: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            if let change { ChangeLabel(text: change, good: good) }
        }
    }
}
