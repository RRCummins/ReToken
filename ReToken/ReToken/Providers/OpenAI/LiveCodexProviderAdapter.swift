import Foundation

struct LiveCodexProviderAdapter: ProviderAdapter {
    let provider: ProviderKind = .codex

    private let apiClient: OpenAIUsageAPIClient
    private let credentialsStore: OpenAICredentialsStore
    private let localSnapshotReader: CodexLocalSnapshotReader
    private let processInfo: ProcessInfo

    init(
        apiClient: OpenAIUsageAPIClient = OpenAIUsageAPIClient(),
        credentialsStore: OpenAICredentialsStore = OpenAICredentialsStore(),
        localSnapshotReader: CodexLocalSnapshotReader = CodexLocalSnapshotReader(),
        processInfo: ProcessInfo = .processInfo
    ) {
        self.apiClient = apiClient
        self.credentialsStore = credentialsStore
        self.localSnapshotReader = localSnapshotReader
        self.processInfo = processInfo
    }

    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle {
        let localBundle = try? localSnapshotReader.readSnapshot(now: context.now)
        let environment = processInfo.environment
        let resolvedCredentials = credentialsStore.loadCredentials()?.resolved(with: environment)
            ?? OpenAICredentials.from(environment: environment)

        guard let credentials = resolvedCredentials else {
            if let localBundle {
                return localBundle
            }

            return unavailableBundle(
                detail: "Save OpenAI admin credentials or use the Codex CLI locally to populate activity"
            )
        }

        do {
            let summary = try await apiClient.fetchDailyUsage(
                adminKey: credentials.adminKey,
                organizationID: credentials.organizationID,
                projectID: credentials.projectID
            )

            if let localBundle {
                return mergedBundle(localBundle: localBundle, summary: summary)
            }

            return apiOnlyBundle(summary: summary, credentials: credentials, now: context.now)
        } catch {
            if let localBundle {
                return localBundle
            }

            return unavailableBundle(detail: error.localizedDescription)
        }
    }

    private func mergedBundle(
        localBundle: ProviderSnapshotBundle,
        summary: OpenAIUsageSummary
    ) -> ProviderSnapshotBundle {
        let tokens = localBundle.usage.todayTokens == 0 ? summary.totalTokens : localBundle.usage.todayTokens
        let requestsSuffix = summary.totalRequests > 0 ? " • org \(summary.totalRequests) req/24h" : ""
        let costSuffix = summary.totalCostUSD.map { String(format: " • org $%.2f today", $0) } ?? ""

        return ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: tokens,
                windowDescription: localBundle.usage.windowDescription + requestsSuffix,
                burnDescription: tokens == localBundle.usage.todayTokens
                    ? localBundle.usage.burnDescription
                    : (tokens > 1_000_000 ? "hot" : "steady"),
                accountStatus: localBundle.usage.accountStatus + " • OpenAI org cost linked"
            ),
            account: AccountSnapshot(
                provider: provider,
                accountLabel: localBundle.account.accountLabel,
                planLabel: localBundle.account.planLabel,
                billingStatus: localBundle.account.billingStatus + costSuffix
            ),
            recentActivity: localBundle.recentActivity,
            issues: localBundle.issues
        )
    }

    private func apiOnlyBundle(
        summary: OpenAIUsageSummary,
        credentials: OpenAICredentials,
        now: Date
    ) -> ProviderSnapshotBundle {
        ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: summary.totalTokens,
                windowDescription: "\(summary.totalRequests) requests in the last 24h",
                burnDescription: summary.totalTokens > 1_000_000 ? "hot" : "steady",
                accountStatus: "OpenAI org usage without local Codex state"
            ),
            account: AccountSnapshot(
                provider: provider,
                accountLabel: credentials.projectID ?? "organization scope",
                planLabel: "OpenAI admin usage",
                billingStatus: summary.totalCostUSD.map { String(format: "$%.2f today", $0) } ?? "cost unavailable"
            ),
            recentActivity: [
                RecentActivityItem(
                    id: "openai:usage-synced",
                    provider: provider,
                    title: "OpenAI usage synced",
                    detail: "Fetched organization completions and costs",
                    occurredAt: now,
                    sourceDescription: "OpenAI Usage API"
                )
            ],
            issues: []
        )
    }

    private func unavailableBundle(detail: String) -> ProviderSnapshotBundle {
        ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: 0,
                windowDescription: "live usage unavailable",
                burnDescription: "idle",
                accountStatus: "waiting for valid OpenAI admin credentials"
            ),
            account: AccountSnapshot(
                provider: provider,
                accountLabel: "not configured",
                planLabel: "OpenAI admin usage",
                billingStatus: "unavailable"
            ),
            recentActivity: [
                RecentActivityItem(
                    id: "openai:usage-unavailable",
                    provider: provider,
                    title: "OpenAI usage unavailable",
                    detail: detail,
                    occurredAt: .now,
                    sourceDescription: "OpenAI Usage API"
                )
            ],
            issues: [
                SnapshotIssue(provider: provider, message: detail)
            ]
        )
    }
}
