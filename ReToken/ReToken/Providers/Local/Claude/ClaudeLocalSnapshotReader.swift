import Foundation

struct ClaudeLocalSnapshotReader: LocalProviderSnapshotReader {
    let provider: ProviderKind = .claude

    private let historyURL: URL
    private let statsCacheURL: URL

    init(
        historyURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/history.jsonl"),
        statsCacheURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/stats-cache.json")
    ) {
        self.historyURL = historyURL
        self.statsCacheURL = statsCacheURL
    }

    func readSnapshot(now: Date) throws -> ProviderSnapshotBundle {
        let historyEntries = (try? loadHistoryEntries()) ?? []
        let statsCache = try? loadStatsCache()

        guard historyEntries.isEmpty == false || statsCache != nil else {
            throw LocalProviderSnapshotError.missingSource(
                "No Claude local history or stats cache found in ~/.claude"
            )
        }

        let todayKey = Self.dayFormatter.string(from: now)
        let latestHistoryEntry = historyEntries.max { $0.timestamp < $1.timestamp }
        let todayActivity = statsCache?.dailyActivity.first(where: { $0.date == todayKey })
        let todayModelTokens = statsCache?.dailyModelTokens.first(where: { $0.date == todayKey })
        let todayTokens = todayModelTokens?.tokensByModel.values.reduce(0, +) ?? 0
        let recentActivity = makeRecentActivity(from: historyEntries)
        let issues = makeIssues(
            historyEntries: historyEntries,
            statsCache: statsCache,
            todayKey: todayKey
        )

        let usage = ProviderUsageSnapshot(
            provider: provider,
            todayTokens: todayTokens,
            windowDescription: makeUsageWindowDescription(
                todayActivity: todayActivity,
                statsCache: statsCache
            ),
            burnDescription: Self.burnDescription(for: todayTokens),
            accountStatus: statsCache == nil ? "recent activity from local history" : "local Claude CLI stats"
        )

        let account = AccountSnapshot(
            provider: provider,
            accountLabel: preferredModelLabel(
                todayModelTokens: todayModelTokens,
                statsCache: statsCache,
                latestProject: latestHistoryEntry?.project
            ),
            planLabel: "Claude local CLI",
            billingStatus: makeBillingStatus(statsCache: statsCache)
        )

        return ProviderSnapshotBundle(
            usage: usage,
            account: account,
            recentActivity: recentActivity,
            issues: issues
        )
    }

    private func loadHistoryEntries() throws -> [ClaudeHistoryEntry] {
        guard FileManager.default.fileExists(atPath: historyURL.path) else {
            return []
        }

        let contents = try String(contentsOf: historyURL, encoding: .utf8)
        let decoder = JSONDecoder()

        return try contents
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                try decoder.decode(ClaudeHistoryEntry.self, from: Data(line.utf8))
            }
    }

    private func loadStatsCache() throws -> ClaudeStatsCache {
        guard FileManager.default.fileExists(atPath: statsCacheURL.path) else {
            throw LocalProviderSnapshotError.missingSource("Claude stats cache is not available")
        }

        let data = try Data(contentsOf: statsCacheURL)
        return try JSONDecoder().decode(ClaudeStatsCache.self, from: data)
    }

    private func makeRecentActivity(from entries: [ClaudeHistoryEntry]) -> [RecentActivityItem] {
        let latestPerSession = Dictionary(grouping: entries, by: \.sessionId)
            .compactMap { _, sessionEntries in
                sessionEntries.max { $0.timestamp < $1.timestamp }
            }
            .sorted { $0.timestamp > $1.timestamp }

        return latestPerSession.prefix(5).map { entry in
            RecentActivityItem(
                id: "claude:session:\(entry.sessionId)",
                provider: provider,
                title: Self.compactTitle(entry.display),
                detail: Self.workspaceName(from: entry.project),
                occurredAt: Date(timeIntervalSince1970: entry.timestamp / 1_000),
                sourceDescription: "Claude local history"
            )
        }
    }

    private func makeUsageWindowDescription(
        todayActivity: ClaudeDailyActivity?,
        statsCache: ClaudeStatsCache?
    ) -> String {
        if let todayActivity {
            return "\(todayActivity.messageCount) msgs • \(todayActivity.sessionCount) sessions today"
        }

        if let lastComputedDate = statsCache?.lastComputedDate {
            return "local stats through \(lastComputedDate)"
        }

        return "local stats unavailable"
    }

    private func makeBillingStatus(statsCache: ClaudeStatsCache?) -> String {
        guard let statsCache else {
            return "local stats unavailable"
        }

        return "\(statsCache.totalMessages) messages • \(statsCache.totalSessions) sessions total"
    }

    private func preferredModelLabel(
        todayModelTokens: ClaudeDailyModelTokens?,
        statsCache: ClaudeStatsCache?,
        latestProject: String?
    ) -> String {
        if let todayModelTokens,
           let topTodayModel = todayModelTokens.tokensByModel.max(by: { $0.value < $1.value })?.key {
            return Self.modelDisplayName(for: topTodayModel)
        }

        if let statsCache,
           let topModel = statsCache.modelUsage.max(by: { $0.value.totalTokens < $1.value.totalTokens })?.key {
            return Self.modelDisplayName(for: topModel)
        }

        if let latestProject {
            return Self.workspaceName(from: latestProject)
        }

        return "local activity"
    }

    private func makeIssues(
        historyEntries: [ClaudeHistoryEntry],
        statsCache: ClaudeStatsCache?,
        todayKey: String
    ) -> [SnapshotIssue] {
        var issues: [SnapshotIssue] = []

        if historyEntries.isEmpty {
            issues.append(
                SnapshotIssue(provider: provider, message: "No Claude local history entries were found")
            )
        }

        guard let statsCache else {
            issues.append(
                SnapshotIssue(provider: provider, message: "Claude token stats cache is unavailable")
            )
            return issues
        }

        if let lastComputedDate = statsCache.lastComputedDate, lastComputedDate != todayKey {
            issues.append(
                SnapshotIssue(provider: provider, message: "Local token stats last updated \(lastComputedDate)")
            )
        }

        return issues
    }

    private static func compactTitle(_ value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > 96 else {
            return normalized
        }

        let endIndex = normalized.index(normalized.startIndex, offsetBy: 96)
        return String(normalized[..<endIndex]) + "…"
    }

    private static func workspaceName(from path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    private static func modelDisplayName(for identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private static func burnDescription(for tokens: Int) -> String {
        switch tokens {
        case 1_000_000...:
            return "furnace"
        case 100_000...:
            return "hot"
        case 1...:
            return "steady"
        default:
            return "idle"
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct ClaudeHistoryEntry: Decodable {
    let display: String
    let project: String
    let sessionId: String
    let timestamp: TimeInterval
}

private struct ClaudeStatsCache: Decodable {
    let dailyActivity: [ClaudeDailyActivity]
    let dailyModelTokens: [ClaudeDailyModelTokens]
    let modelUsage: [String: ClaudeModelUsage]
    let totalMessages: Int
    let totalSessions: Int
    let lastComputedDate: String?
}

private struct ClaudeDailyActivity: Decodable {
    let date: String
    let messageCount: Int
    let sessionCount: Int
}

private struct ClaudeDailyModelTokens: Decodable {
    let date: String
    let tokensByModel: [String: Int]
}

private struct ClaudeModelUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadInputTokens: Int
    let cacheCreationInputTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheReadInputTokens + cacheCreationInputTokens
    }
}
