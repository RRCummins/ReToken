import Foundation

enum AppSnapshotFormatter {
    static func statusTitle(for snapshot: AppSnapshot) -> String {
        let warningMarker = snapshot.issues.isEmpty ? "" : " !"
        return "RT \(compactTokenCount(snapshot.totalTodayTokens))\(warningMarker)"
    }

    static func tooltip(for snapshot: AppSnapshot) -> String {
        "ReToken • \(compactTokenCount(snapshot.totalTodayTokens)) tokens today • \(snapshot.mode.displayName) • \(snapshot.freshness.displayName)"
    }

    static func lastUpdatedLine(for snapshot: AppSnapshot) -> String {
        "Last updated \(timeFormatter.string(from: snapshot.lastUpdatedAt)) • \(snapshot.mode.displayName.lowercased()) • \(snapshot.freshness.displayName) • \(snapshot.dataSourceLabel)"
    }

    static func issuesMenuLine(for issue: SnapshotIssue) -> String {
        if let provider = issue.provider {
            return "\(provider.displayName): \(issue.message)"
        }

        return issue.message
    }

    static func issuesDashboardText(for snapshot: AppSnapshot) -> String {
        guard snapshot.issues.isEmpty == false else {
            return "No active issues"
        }

        return snapshot.issues
            .map { issue in
                if let provider = issue.provider {
                    return "\(provider.displayName): \(issue.message)"
                }

                return issue.message
            }
            .joined(separator: "\n")
    }

    static func usageMenuLine(for snapshot: ProviderUsageSnapshot) -> String {
        "\(snapshot.provider.displayName): \(compactTokenCount(snapshot.todayTokens)) today • \(snapshot.windowDescription)"
    }

    static func accountMenuLine(for snapshot: AccountSnapshot) -> String {
        "\(snapshot.provider.displayName): \(snapshot.planLabel) • \(snapshot.accountLabel)"
    }

    static func activityMenuLine(for item: RecentActivityItem) -> String {
        "\(item.provider.displayName): \(item.title) • \(relativeFormatter.localizedString(for: item.occurredAt, relativeTo: .now))"
    }

    static func usageDashboardText(for snapshot: AppSnapshot) -> String {
        snapshot.usage
            .map {
                "\($0.provider.displayName): \(compactTokenCount($0.todayTokens)) today, \($0.windowDescription), \($0.burnDescription) burn, \($0.accountStatus)"
            }
            .joined(separator: "\n")
    }

    static func accountsDashboardText(for snapshot: AppSnapshot) -> String {
        snapshot.accounts
            .map { "\($0.provider.displayName): \($0.planLabel) • \($0.accountLabel) • \($0.billingStatus)" }
            .joined(separator: "\n")
    }

    static func activityDashboardText(for snapshot: AppSnapshot) -> String {
        snapshot.recentActivity
            .map {
                let relative = relativeFormatter.localizedString(for: $0.occurredAt, relativeTo: .now)
                return "\($0.provider.displayName): \($0.title) • \($0.detail) • \(relative) • \($0.sourceDescription)"
            }
            .joined(separator: "\n")
    }

    static func modeMenuLine(for snapshot: AppSnapshot) -> String {
        "Provider mode: \(snapshot.mode.displayName) • cache: \(snapshot.freshness.displayName)"
    }

    static func refreshMenuLine(intervalMinutes: Int) -> String {
        "Automatic refresh every \(intervalMinutes)m"
    }

    static func trackingMenuLine(for summary: UsageTrackingSummary) -> String {
        guard summary.isEmpty == false else {
            return "Tracking: no usage samples recorded yet"
        }

        let agentLabel = "\(summary.trackedProviderCount) agents"
        let lastRecordedText = summary.lastRecordedAt.map { timeFormatter.string(from: $0) } ?? "unknown"
        let peakLabel = summary.peakProvider.map {
            "\($0.displayName) \(compactTokenCount(summary.peakTokens))"
        } ?? compactTokenCount(summary.peakTokens)

        return "Tracking: \(summary.sampleCount) samples • \(agentLabel) • peak \(peakLabel) • last \(lastRecordedText)"
    }

    static func trackingDashboardText(for snapshot: AppSnapshot) -> String {
        let summary = snapshot.usageTrackingSummary

        guard summary.isEmpty == false else {
            return "No tracked usage yet"
        }

        let lastRecordedText = summary.lastRecordedAt.map {
            relativeFormatter.localizedString(for: $0, relativeTo: .now)
        } ?? "unknown"
        let peakLabel = summary.peakProvider.map {
            "\($0.displayName) \(compactTokenCount(summary.peakTokens))"
        } ?? compactTokenCount(summary.peakTokens)

        return "\(summary.sampleCount) samples across \(summary.trackedProviderCount) agents • peak \(peakLabel) • last record \(lastRecordedText)"
    }

    static func leaderboardMenuLines(for summary: UsageLeaderboardSummary) -> [String] {
        guard summary.isEmpty == false else {
            return ["Leaderboards: waiting for enough telemetry"]
        }

        let currentRunLabel = summary.currentRunRank.map { "#\($0) current run" } ?? "current run unranked"
        let bestTotalLabel = "best total \(compactTokenCount(summary.bestRecordedTotal))"
        let championLabel = summary.championEntry.map {
            "champ \($0.provider.displayName) \(compactTokenCount($0.bestTokens))"
        } ?? "champ pending"
        let mostTrackedLabel = summary.mostTrackedProvider.map {
            "most tracked \($0.displayName) x\(summary.mostTrackedSampleCount)"
        } ?? "tracking history warming up"

        return [
            "Leaderboards: \(currentRunLabel) • \(bestTotalLabel)",
            "\(championLabel) • \(mostTrackedLabel)"
        ]
    }

    static func leaderboardDashboardText(for snapshot: AppSnapshot) -> String {
        let summary = snapshot.leaderboardSummary

        guard summary.isEmpty == false else {
            return "No leaderboard history yet"
        }

        let currentRunLine = summary.currentRunRank.map {
            "Current run rank: #\($0) all time"
        } ?? "Current run rank: warming up"
        let bestRecordedLine = "Best combined burn: \(compactTokenCount(summary.bestRecordedTotal))"
        let championLine = summary.championEntry.map {
            "All-time champ: \($0.provider.displayName) • \(compactTokenCount($0.bestTokens)) best sample • \($0.sampleCount) samples"
        } ?? "All-time champ: pending"
        let mostTrackedLine = summary.mostTrackedProvider.map {
            "Most tracked: \($0.displayName) • \(summary.mostTrackedSampleCount) snapshots"
        } ?? "Most tracked: pending"
        let providerLines = summary.providerBests.prefix(3).enumerated().map { index, entry in
            "\(index + 1). \(entry.provider.displayName) • \(compactTokenCount(entry.bestTokens)) best • \(entry.sampleCount) samples"
        }

        return ([currentRunLine, bestRecordedLine, championLine, mostTrackedLine] + providerLines).joined(separator: "\n")
    }

    static func compactTokenCount(_ value: Int) -> String {
        switch value {
        case 1_000_000...:
            return String(format: "%.1fM", Double(value) / 1_000_000)
        case 1_000...:
            return String(format: "%.1fK", Double(value) / 1_000)
        default:
            return "\(value)"
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
