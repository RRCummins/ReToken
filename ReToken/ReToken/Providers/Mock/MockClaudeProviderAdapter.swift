import Foundation

struct MockClaudeProviderAdapter: ProviderAdapter {
    let provider: ProviderKind = .claude

    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle {
        let tokens = 920_000 + (context.refreshCount * 11_000)

        return ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: tokens,
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
