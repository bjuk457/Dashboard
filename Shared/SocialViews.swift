import SwiftUI

struct PlatformBadge: View {
    let platform: SocialPlatform

    var body: some View {
        Text(platform.shortName)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(platform == .instagram ? Color.pink : Color.blue)
            )
    }
}

/// "IG 2.480 +36" in one line.
struct FollowersLine: View {
    let report: SocialReport

    var body: some View {
        HStack(spacing: 4) {
            PlatformBadge(platform: report.platform)
            Text(report.followers.map(Fmt.number) ?? "–")
                .font(.caption.weight(.semibold).monospacedDigit())
            if let change = report.followersChange {
                ChangeLabel(text: Fmt.signed(change), good: change == 0 ? nil : change > 0)
            }
        }
    }
}

/// One account with followers, period figures and optionally the latest posts.
struct SocialCard: View {
    let report: SocialReport
    var postLimit = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                PlatformBadge(platform: report.platform)
                Text(report.displayName).font(.caption.weight(.semibold)).lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(report.followers.map(Fmt.number) ?? "–")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                Text("Follower").font(.caption2).foregroundStyle(.secondary)
                if let change = report.followersChange {
                    ChangeLabel(text: Fmt.signed(change), good: change == 0 ? nil : change > 0)
                }
            }
            ForEach(report.metrics) { metric in
                HStack(spacing: 4) {
                    Text(metric.label).font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 2)
                    Text(Fmt.compact(metric.value)).font(.caption2.weight(.medium).monospacedDigit())
                    if metric.previous != nil {
                        ChangeLabel(
                            text: Fmt.signedPercent(metric.changePercent),
                            good: metric.changePercent.map { $0 >= 0 }
                        )
                        .frame(width: 44, alignment: .trailing)
                    }
                }
            }
            if postLimit > 0, !report.posts.isEmpty {
                Text("Letzte Beiträge").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.top, 2)
                ForEach(report.posts.prefix(postLimit)) { post in
                    HStack(spacing: 4) {
                        Text(post.text).font(.caption2).lineLimit(1)
                        Spacer(minLength: 2)
                        Label(Fmt.compact(post.likes), systemImage: "heart")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        Label(Fmt.compact(post.comments), systemImage: "bubble.right")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .labelStyle(CompactLabelStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 1) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
