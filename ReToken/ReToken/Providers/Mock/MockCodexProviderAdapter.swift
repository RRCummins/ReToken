import Foundation

struct MockCodexProviderAdapter: ProviderAdapter {
    let provider: ProviderKind = .codex

    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle {
        let tokens = 610_000 + (context.refreshCount * 7_000)

        return ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: tokens,
                windowDescription: "weekly budget at 63%",
                burnDescription: "steady",
                accountStatus: "connected through usage API"
            ),
            account: AccountSnapshot(
                provider: provider,
                accountLabel: "team themrhinos",
                planLabel: "pay-as-you-go",
                billingStatus: "active"
            ),
            recentActivity: [
                RecentActivityItem(
                    id: "mock:codex:appkit-shell",
                    provider: provider,
                    title: "Review AppKit shell",
                    detail: "Status item and dashboard bootstrap pass",
                    occurredAt: context.now.addingTimeInterval(-39 * 60),
                    sourceDescription: "mock provider activity"
                )
            ],
            issues: []
        )
    }
}
