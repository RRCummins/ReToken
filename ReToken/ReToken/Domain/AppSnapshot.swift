import Foundation

struct AppSnapshot: Codable {
    let usage: [ProviderUsageSnapshot]
    let accounts: [AccountSnapshot]
    let recentActivity: [RecentActivityItem]
    let usageTrackingSummary: UsageTrackingSummary
    let leaderboardSummary: UsageLeaderboardSummary
    let lastUpdatedAt: Date
    let mode: ProviderMode
    let freshness: SnapshotFreshness
    let dataSourceLabel: String
    let issues: [SnapshotIssue]

    init(
        usage: [ProviderUsageSnapshot],
        accounts: [AccountSnapshot],
        recentActivity: [RecentActivityItem],
        usageTrackingSummary: UsageTrackingSummary = .empty,
        leaderboardSummary: UsageLeaderboardSummary = .empty,
        lastUpdatedAt: Date,
        mode: ProviderMode,
        freshness: SnapshotFreshness,
        dataSourceLabel: String,
        issues: [SnapshotIssue]
    ) {
        self.usage = usage
        self.accounts = accounts
        self.recentActivity = recentActivity
        self.usageTrackingSummary = usageTrackingSummary
        self.leaderboardSummary = leaderboardSummary
        self.lastUpdatedAt = lastUpdatedAt
        self.mode = mode
        self.freshness = freshness
        self.dataSourceLabel = dataSourceLabel
        self.issues = issues
    }

    var totalTodayTokens: Int {
        usage.reduce(0) { $0 + $1.todayTokens }
    }

    func replacing(
        freshness: SnapshotFreshness,
        dataSourceLabel newDataSourceLabel: String? = nil,
        recentActivity: [RecentActivityItem]? = nil,
        usageTrackingSummary: UsageTrackingSummary? = nil,
        leaderboardSummary: UsageLeaderboardSummary? = nil,
        issues: [SnapshotIssue]? = nil
    ) -> AppSnapshot {
        AppSnapshot(
            usage: usage,
            accounts: accounts,
            recentActivity: recentActivity ?? self.recentActivity,
            usageTrackingSummary: usageTrackingSummary ?? self.usageTrackingSummary,
            leaderboardSummary: leaderboardSummary ?? self.leaderboardSummary,
            lastUpdatedAt: lastUpdatedAt,
            mode: mode,
            freshness: freshness,
            dataSourceLabel: newDataSourceLabel ?? dataSourceLabel,
            issues: issues ?? self.issues
        )
    }

    private enum CodingKeys: String, CodingKey {
        case usage
        case accounts
        case recentActivity
        case usageTrackingSummary
        case leaderboardSummary
        case lastUpdatedAt
        case mode
        case freshness
        case dataSourceLabel
        case issues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usage = try container.decode([ProviderUsageSnapshot].self, forKey: .usage)
        accounts = try container.decode([AccountSnapshot].self, forKey: .accounts)
        recentActivity = try container.decode([RecentActivityItem].self, forKey: .recentActivity)
        usageTrackingSummary = try container.decodeIfPresent(UsageTrackingSummary.self, forKey: .usageTrackingSummary) ?? .empty
        leaderboardSummary = try container.decodeIfPresent(UsageLeaderboardSummary.self, forKey: .leaderboardSummary) ?? .empty
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
        mode = try container.decode(ProviderMode.self, forKey: .mode)
        freshness = try container.decode(SnapshotFreshness.self, forKey: .freshness)
        dataSourceLabel = try container.decode(String.self, forKey: .dataSourceLabel)
        issues = try container.decode([SnapshotIssue].self, forKey: .issues)
    }
}
