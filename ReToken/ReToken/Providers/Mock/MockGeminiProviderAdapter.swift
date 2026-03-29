import Foundation

struct MockGeminiProviderAdapter: ProviderAdapter {
    let provider: ProviderKind = .gemini

    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle {
        let tokens = 280_000 + (context.refreshCount * 5_000)

        return ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: tokens,
                todayInputTokens: 176_000 + (context.refreshCount * 3_000),
                todayOutputTokens: 104_000 + (context.refreshCount * 2_000),
                fiveHourTokens: 74_000 + (context.refreshCount * 1_500),
                weekTokens: 1_520_000 + (context.refreshCount * 8_000),
                windowDescription: "project quota healthy",
                burnDescription: "warming up",
                accountStatus: "connected through project metrics"
            ),
            account: AccountSnapshot(
                provider: provider,
                accountLabel: "studio sandbox",
                planLabel: "tier 1 paid",
                billingStatus: "active"
            ),
            recentActivity: [
                RecentActivityItem(
                    id: "mock:gemini:quota-sanity",
                    provider: provider,
                    title: "Quota sanity check",
                    detail: "Rate limit comparison across models",
                    occurredAt: context.now.addingTimeInterval(-86 * 60),
                    sourceDescription: "mock project metrics"
                )
            ],
            issues: []
        )
    }
}
