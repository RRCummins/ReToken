import Foundation

struct ClaudeLocalSnapshotReader: LocalProviderSnapshotReader {
    let provider: ProviderKind = .claude

    private let historyURL: URL
    private let statsCacheURL: URL
    private let projectsDirectoryURL: URL

    init(
        historyURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/history.jsonl"),
        statsCacheURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/stats-cache.json"),
        projectsDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/projects")
    ) {
        self.historyURL = historyURL
        self.statsCacheURL = statsCacheURL
        self.projectsDirectoryURL = projectsDirectoryURL
    }

    func readSnapshot(now: Date) throws -> ProviderSnapshotBundle {
        let historyEntries = (try? loadHistoryEntries()) ?? []
        let statsCache = try? loadStatsCache()
        let projectSummary = loadProjectTokenWindows(now: now)

        guard historyEntries.isEmpty == false || statsCache != nil || projectSummary.todayTokens > 0 else {
            throw LocalProviderSnapshotError.missingSource(
                "No Claude local history, stats cache, or project files found in ~/.claude"
            )
        }

        let todayKey = Self.dayFormatter.string(from: now)
        let latestHistoryEntry = historyEntries.max { $0.timestamp < $1.timestamp }
        let todayActivity = statsCache?.dailyActivity.first(where: { $0.date == todayKey })
        let todayModelTokens = statsCache?.dailyModelTokens.first(where: { $0.date == todayKey })

        let todayTokens = projectSummary.todayTokens > 0
            ? projectSummary.todayTokens
            : (todayModelTokens?.tokensByModel.values.reduce(0, +) ?? 0)
        let fiveHourTokens = projectSummary.fiveHourTokens
        let weekTokens = projectSummary.weekTokens > 0
            ? projectSummary.weekTokens
            : weekTokensFromStatsCache(statsCache: statsCache, now: now)
        let statsCacheLifetime = statsCache?.modelUsage.values.reduce(0) { $0 + $1.totalTokens } ?? 0
        let lifetimeTokens = statsCacheLifetime + projectSummary.todayTokens

        let recentActivity = makeRecentActivity(from: historyEntries)
        let issues = makeIssues(
            historyEntries: historyEntries,
            statsCache: statsCache,
            todayKey: todayKey,
            projectSummaryHasTokens: projectSummary.todayTokens > 0
        )

        let usage = ProviderUsageSnapshot(
            provider: provider,
            todayTokens: todayTokens,
            todayInputTokens: projectSummary.hasTodaySplit ? projectSummary.todayInputTokens : nil,
            todayOutputTokens: projectSummary.hasTodaySplit ? projectSummary.todayOutputTokens : nil,
            fiveHourTokens: fiveHourTokens,
            weekTokens: weekTokens,
            lifetimeTokens: lifetimeTokens,
            windowDescription: makeUsageWindowDescription(
                todayActivity: todayActivity,
                statsCache: statsCache,
                projectSummary: projectSummary
            ),
            burnDescription: Self.burnDescription(for: todayTokens),
            accountStatus: statsCache == nil ? "recent activity from local history" : "local Claude CLI stats"
        )

        let account = AccountSnapshot(
            provider: provider,
            accountLabel: preferredModelLabel(
                projectTopModel: projectSummary.topModel,
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

    // MARK: - Project JSONL scanning

    private func loadProjectTokenWindows(now: Date) -> ClaudeProjectTokenSummary {
        let fm = FileManager.default
        guard fm.fileExists(atPath: projectsDirectoryURL.path) else {
            return .zero
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let fiveHourBoundary = now.addingTimeInterval(-(5 * 60 * 60))
        let weekBoundary = now.addingTimeInterval(-(7 * 24 * 60 * 60))

        var todayTokens = 0
        var todayInputTokens = 0
        var todayOutputTokens = 0
        var fiveHourTokens = 0
        var weekTokens = 0
        var modelCounts: [String: Int] = [:]

        let projectURLs: [URL]
        do {
            projectURLs = try fm.contentsOfDirectory(
                at: projectsDirectoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return .zero
        }

        for projectURL in projectURLs {
            guard (try? projectURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }

            let jsonlFiles: [URL]
            do {
                jsonlFiles = try fm.contentsOfDirectory(
                    at: projectURL,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                ).filter { $0.pathExtension == "jsonl" }
            } catch {
                continue
            }

            for fileURL in jsonlFiles {
                if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modDate < weekBoundary {
                    continue
                }

                guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    continue
                }

                for line in contents.split(whereSeparator: \.isNewline) {
                    guard let data = line.utf8Data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let type = json["type"] as? String,
                          type == "assistant",
                          let timestampString = json["timestamp"] as? String,
                          let timestamp = Self.parseISO(timestampString),
                          calendar.isDate(timestamp, inSameDayAs: now),
                          let message = json["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any]
                    else {
                        continue
                    }

                    let input = usage["input_tokens"] as? Int ?? 0
                    let output = usage["output_tokens"] as? Int ?? 0
                    let cacheCreate = usage["cache_creation_input_tokens"] as? Int ?? 0
                    let cacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                    let effectiveInput = input + cacheCreate + cacheRead
                    let totalTokens = input + output + cacheCreate + cacheRead

                    if timestamp >= weekBoundary {
                        weekTokens += totalTokens
                    }

                    if timestamp >= fiveHourBoundary {
                        fiveHourTokens += totalTokens
                    }

                    guard timestamp >= startOfDay else {
                        continue
                    }

                    todayTokens += totalTokens
                    todayInputTokens += effectiveInput
                    todayOutputTokens += output

                    if let model = message["model"] as? String {
                        modelCounts[model, default: 0] += totalTokens
                    }
                }
            }
        }

        let topModel = modelCounts.max(by: { $0.value < $1.value })?.key
        return ClaudeProjectTokenSummary(
            todayTokens: todayTokens,
            todayInputTokens: todayInputTokens,
            todayOutputTokens: todayOutputTokens,
            fiveHourTokens: fiveHourTokens,
            weekTokens: weekTokens,
            topModel: topModel
        )
    }

    // MARK: - History loading

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

    // MARK: - Recent activity

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

    // MARK: - Descriptions

    private func makeUsageWindowDescription(
        todayActivity: ClaudeDailyActivity?,
        statsCache: ClaudeStatsCache?,
        projectSummary: ClaudeProjectTokenSummary
    ) -> String {
        if let todayActivity {
            return "\(todayActivity.messageCount) msgs • \(todayActivity.sessionCount) sessions today"
        }

        if projectSummary.todayTokens > 0 || projectSummary.fiveHourTokens > 0 || projectSummary.weekTokens > 0 {
            return "live project data"
        }

        if let lastComputedDate = statsCache?.lastComputedDate {
            return "local stats through \(lastComputedDate)"
        }

        return "local stats unavailable"
    }

    private func weekTokensFromStatsCache(statsCache: ClaudeStatsCache?, now: Date) -> Int {
        guard let statsCache else {
            return 0
        }

        let calendar = Calendar.current
        let weekBoundaryStart = calendar.startOfDay(for: now.addingTimeInterval(-(7 * 24 * 60 * 60)))

        return statsCache.dailyModelTokens.reduce(0) { partialResult, entry in
            guard let entryDate = Self.dayFormatter.date(from: entry.date),
                  entryDate >= weekBoundaryStart else {
                return partialResult
            }

            return partialResult + entry.tokensByModel.values.reduce(0, +)
        }
    }

    private func makeBillingStatus(statsCache: ClaudeStatsCache?) -> String {
        guard let statsCache else {
            return "local stats unavailable"
        }

        return "\(statsCache.totalMessages) messages • \(statsCache.totalSessions) sessions total"
    }

    private func preferredModelLabel(
        projectTopModel: String?,
        todayModelTokens: ClaudeDailyModelTokens?,
        statsCache: ClaudeStatsCache?,
        latestProject: String?
    ) -> String {
        // Project scan model takes priority since it reflects real today usage
        if let projectTopModel {
            return Self.modelDisplayName(for: projectTopModel)
        }

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
        todayKey: String,
        projectSummaryHasTokens: Bool
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

        // Only report stale stats cache if project scanning didn't find today's tokens
        if !projectSummaryHasTokens,
           let lastComputedDate = statsCache.lastComputedDate,
           lastComputedDate != todayKey {
            issues.append(
                SnapshotIssue(provider: provider, message: "Local token stats last updated \(lastComputedDate)")
            )
        }

        return issues
    }

    // MARK: - ISO 8601 parsing

    private static let isoWithFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoWithoutFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseISO(_ value: String) -> Date? {
        isoWithFractionalSeconds.date(from: value) ?? isoWithoutFractionalSeconds.date(from: value)
    }

    // MARK: - Formatting helpers

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

// MARK: - Private data types

private struct ClaudeProjectTokenSummary {
    static let zero = ClaudeProjectTokenSummary(
        todayTokens: 0,
        todayInputTokens: 0,
        todayOutputTokens: 0,
        fiveHourTokens: 0,
        weekTokens: 0,
        topModel: nil
    )
    let todayTokens: Int
    let todayInputTokens: Int
    let todayOutputTokens: Int
    let fiveHourTokens: Int
    let weekTokens: Int
    let topModel: String?

    var hasTodaySplit: Bool {
        todayTokens > 0
    }
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

// MARK: - String utility

private extension StringProtocol {
    var utf8Data: Data? {
        Data(utf8)
    }
}
