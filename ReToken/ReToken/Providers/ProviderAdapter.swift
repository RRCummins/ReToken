import Foundation

struct ProviderFetchContext {
    let refreshCount: Int
    let now: Date
}

struct ProviderSnapshotBundle {
    let usage: ProviderUsageSnapshot
    let account: AccountSnapshot
    let recentActivity: [RecentActivityItem]
    let issues: [SnapshotIssue]
}

protocol ProviderAdapter {
    var provider: ProviderKind { get }
    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle
}
