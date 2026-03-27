import Foundation

struct LiveClaudeProviderAdapter: ProviderAdapter {
    let provider: ProviderKind = .claude
    private let localSnapshotReader: ClaudeLocalSnapshotReader

    init(localSnapshotReader: ClaudeLocalSnapshotReader = ClaudeLocalSnapshotReader()) {
        self.localSnapshotReader = localSnapshotReader
    }

    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle {
        do {
            return try localSnapshotReader.readSnapshot(now: context.now)
        } catch {
            return unavailableBundle(detail: error.localizedDescription, now: context.now)
        }
    }

    private func unavailableBundle(detail: String, now: Date) -> ProviderSnapshotBundle {
        ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: 0,
                windowDescription: "Claude local data unavailable",
                burnDescription: "idle",
                accountStatus: "waiting for local Claude telemetry"
            ),
            account: AccountSnapshot(
                provider: provider,
                accountLabel: "not configured",
                planLabel: "Claude local CLI",
                billingStatus: "unavailable"
            ),
            recentActivity: [
                RecentActivityItem(
                    id: "live:claude:local-history-unavailable",
                    provider: provider,
                    title: "Claude local history unavailable",
                    detail: detail,
                    occurredAt: now,
                    sourceDescription: "Claude local files"
                )
            ],
            issues: [
                SnapshotIssue(provider: provider, message: detail)
            ]
        )
    }
}
