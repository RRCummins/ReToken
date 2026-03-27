import Foundation
@testable import ReToken

enum SnapshotFixtures {
    static func usage(
        provider: ProviderKind,
        todayTokens: Int,
        windowDescription: String = "24h window",
        burnDescription: String = "high",
        accountStatus: String = "Healthy"
    ) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            provider: provider,
            todayTokens: todayTokens,
            windowDescription: windowDescription,
            burnDescription: burnDescription,
            accountStatus: accountStatus
        )
    }

    static func account(
        provider: ProviderKind,
        accountLabel: String = "primary",
        planLabel: String = "pro",
        billingStatus: String = "active"
    ) -> AccountSnapshot {
        AccountSnapshot(
            provider: provider,
            accountLabel: accountLabel,
            planLabel: planLabel,
            billingStatus: billingStatus
        )
    }

    static func activity(
        id: String? = nil,
        provider: ProviderKind,
        title: String,
        detail: String = "Conversation detail",
        occurredAt: Date,
        sourceDescription: String = "fixture"
    ) -> RecentActivityItem {
        RecentActivityItem(
            id: id,
            provider: provider,
            title: title,
            detail: detail,
            occurredAt: occurredAt,
            sourceDescription: sourceDescription
        )
    }

    static func snapshot(
        usage: [ProviderUsageSnapshot],
        accounts: [AccountSnapshot]? = nil,
        recentActivity: [RecentActivityItem] = [],
        usageTrackingSummary: UsageTrackingSummary = .empty,
        leaderboardSummary: UsageLeaderboardSummary = .empty,
        lastUpdatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        mode: ProviderMode = .mock,
        freshness: SnapshotFreshness = .fresh,
        dataSourceLabel: String = "Fixtures",
        issues: [SnapshotIssue] = []
    ) -> AppSnapshot {
        AppSnapshot(
            usage: usage,
            accounts: accounts ?? usage.map { account(provider: $0.provider) },
            recentActivity: recentActivity,
            usageTrackingSummary: usageTrackingSummary,
            leaderboardSummary: leaderboardSummary,
            lastUpdatedAt: lastUpdatedAt,
            mode: mode,
            freshness: freshness,
            dataSourceLabel: dataSourceLabel,
            issues: issues
        )
    }
}
