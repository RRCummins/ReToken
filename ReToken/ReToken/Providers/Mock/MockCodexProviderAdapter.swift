import Foundation

struct MockCodexProviderAdapter: ProviderAdapter {
    let provider: ProviderKind = .codex

    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle {
        let tokens = 610_000 + (context.refreshCount * 7_000)

        return ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: tokens,
                todayInputTokens: 402_000 + (context.refreshCount * 4_500),
                todayOutputTokens: 208_000 + (context.refreshCount * 2_500),
                fiveHourTokens: 146_000 + (context.refreshCount * 2_500),
                weekTokens: 3_880_000 + (context.refreshCount * 11_000),
                fiveHourUsedPercent: 46,
                fiveHourResetAt: context.now.addingTimeInterval(72 * 60),
                weekUsedPercent: 19,
                weekResetAt: context.now.addingTimeInterval((6 * 24 * 60 * 60) + (19 * 60 * 60)),
                lifetimeTokens: 396_100_000,
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
