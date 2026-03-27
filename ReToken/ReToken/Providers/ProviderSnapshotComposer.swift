import Foundation

enum ProviderSnapshotComposer {
    static func makeSnapshot(
        from adapters: [any ProviderAdapter],
        mode: ProviderMode,
        refreshCount: Int,
        now: Date = .now,
        freshness: SnapshotFreshness,
        dataSourceLabel: String
    ) async -> AppSnapshot {
        let context = ProviderFetchContext(refreshCount: refreshCount, now: now)
        var bundles: [ProviderSnapshotBundle] = []
        bundles.reserveCapacity(adapters.count)

        for adapter in adapters {
            let bundle = await adapter.fetchSnapshot(context: context)
            bundles.append(bundle)
        }

        return AppSnapshot(
            usage: bundles.map(\.usage).sorted { $0.provider.rawValue < $1.provider.rawValue },
            accounts: bundles.map(\.account).sorted { $0.provider.rawValue < $1.provider.rawValue },
            recentActivity: bundles
                .flatMap(\.recentActivity)
                .sorted { $0.occurredAt > $1.occurredAt },
            lastUpdatedAt: now,
            mode: mode,
            freshness: freshness,
            dataSourceLabel: dataSourceLabel,
            issues: bundles.flatMap(\.issues)
        )
    }
}
