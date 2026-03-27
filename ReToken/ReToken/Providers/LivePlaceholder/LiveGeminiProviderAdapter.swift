import Foundation

struct LiveGeminiProviderAdapter: ProviderAdapter {
    let provider: ProviderKind = .gemini

    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle {
        ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: 0,
                windowDescription: "live adapter not wired",
                burnDescription: "idle",
                accountStatus: "waiting for real integration"
            ),
            account: AccountSnapshot(
                provider: provider,
                accountLabel: "not configured",
                planLabel: "live mode pending",
                billingStatus: "unavailable"
            ),
            recentActivity: [
                RecentActivityItem(
                    id: "live:gemini:unavailable",
                    provider: provider,
                    title: "Live activity unavailable",
                    detail: "Gemini live integration has not been implemented yet",
                    occurredAt: context.now,
                    sourceDescription: "live placeholder"
                )
            ],
            issues: [
                SnapshotIssue(provider: provider, message: "Gemini live adapter not implemented")
            ]
        )
    }
}
