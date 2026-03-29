import Foundation

struct MockClaudeProviderAdapter: ProviderAdapter {
    let provider: ProviderKind = .claude

    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle {
        let tokens = 920_000 + (context.refreshCount * 11_000)

        return ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: tokens,
                todayInputTokens: 708_000 + (context.refreshCount * 8_500),
                todayOutputTokens: 212_000 + (context.refreshCount * 2_500),
                fiveHourTokens: 284_000 + (context.refreshCount * 4_000),
                weekTokens: 2_460_000 + (context.refreshCount * 15_000),
                lifetimeTokens: 48_200_000,
                windowDescription: "5h window resets in 1h 24m",
                burnDescription: "hot",
                accountStatus: "connected through local CLI usage"
            ),
            account: AccountSnapshot(
                provider: provider,
                accountLabel: "ryan@example.com",
                planLabel: "Max 20x",
                billingStatus: "active"
            ),
            recentActivity: [
                RecentActivityItem(
                    id: "mock:claude:menu-state",
                    provider: provider,
                    title: "Refactor menu state",
                    detail: "Large context session with cache-heavy follow-ups",
                    occurredAt: context.now.addingTimeInterval(-14 * 60),
                    sourceDescription: "mock local history"
                )
            ],
            issues: []
        )
    }
}
