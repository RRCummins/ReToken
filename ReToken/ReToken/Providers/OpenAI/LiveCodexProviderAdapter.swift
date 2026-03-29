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
            let summary = try await apiClient.fetchUsageWindows(
                adminKey: credentials.adminKey,
                organizationID: credentials.organizationID,
                projectID: credentials.projectID,
                now: context.now
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
        let todayTokens = localBundle.usage.todayTokens == 0 ? summary.todayTokens : localBundle.usage.todayTokens
        let todayInputTokens = localBundle.usage.todayInputTokens ?? summary.todayInputTokens
        let todayOutputTokens = localBundle.usage.todayOutputTokens ?? summary.todayOutputTokens
        let fiveHourTokens = localBundle.usage.fiveHourTokens == 0 ? summary.fiveHourTokens : localBundle.usage.fiveHourTokens
        let weekTokens = localBundle.usage.weekTokens == 0 ? summary.weekTokens : localBundle.usage.weekTokens
        let requestsSuffix = summary.todayRequests > 0 ? " • org \(summary.todayRequests) req today" : ""
        let costSuffix = summary.todayCostUSD.map { String(format: " • org $%.2f today", $0) } ?? ""

        return ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: todayTokens,
                todayInputTokens: todayInputTokens,
                todayOutputTokens: todayOutputTokens,
                fiveHourTokens: fiveHourTokens,
                weekTokens: weekTokens,
                fiveHourUsedPercent: localBundle.usage.fiveHourUsedPercent,
                fiveHourResetAt: localBundle.usage.fiveHourResetAt,
                weekUsedPercent: localBundle.usage.weekUsedPercent,
                weekResetAt: localBundle.usage.weekResetAt,
                lifetimeTokens: localBundle.usage.lifetimeTokens,
                windowDescription: localBundle.usage.windowDescription + requestsSuffix,
                burnDescription: todayTokens == localBundle.usage.todayTokens
                    ? localBundle.usage.burnDescription
                    : (todayTokens > 1_000_000 ? "hot" : "steady"),
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
                todayTokens: summary.todayTokens,
                todayInputTokens: summary.todayInputTokens,
                todayOutputTokens: summary.todayOutputTokens,
                fiveHourTokens: summary.fiveHourTokens,
                weekTokens: summary.weekTokens,
                windowDescription: "\(summary.todayRequests) requests today via OpenAI admin usage",
                burnDescription: summary.todayTokens > 1_000_000 ? "hot" : "steady",
                accountStatus: "OpenAI org usage without local Codex state"
            ),
            account: AccountSnapshot(
                provider: provider,
                accountLabel: credentials.projectID ?? "organization scope",
                planLabel: "OpenAI admin usage",
                billingStatus: summary.todayCostUSD.map { String(format: "$%.2f today", $0) } ?? "cost unavailable"
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
                accountStatus: "waiting for valid OpenAI admin credentials",
                isVisible: false
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
