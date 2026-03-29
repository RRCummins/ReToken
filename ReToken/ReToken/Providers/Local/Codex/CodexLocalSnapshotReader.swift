import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

struct CodexLocalSnapshotReader: LocalProviderSnapshotReader {
    let provider: ProviderKind = .codex

    private let stateDatabaseURL: URL

    init(
        stateDatabaseURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/state_5.sqlite")
    ) {
        self.stateDatabaseURL = stateDatabaseURL
    }

    func readSnapshot(now: Date) throws -> ProviderSnapshotBundle {
        #if canImport(SQLite3)
        let recentThreads = try loadRecentThreads(limit: 5)
        guard let latestThread = recentThreads.first else {
            throw LocalProviderSnapshotError.invalidSource("Codex local state database contains no threads")
        }

        let aggregate = try loadTodayAggregate(now: now)
        let lifetimeTokens = (try? loadLifetimeTokens()) ?? 0
        let rateSnapshot = recentThreads.lazy.compactMap { try? loadRateSnapshot(from: $0.rolloutPath) }.first

        let usage = ProviderUsageSnapshot(
            provider: provider,
            todayTokens: aggregate.totalTokens,
            todayInputTokens: aggregate.todayInputTokens,
            todayOutputTokens: aggregate.todayOutputTokens,
            fiveHourTokens: aggregate.fiveHourTokens,
            weekTokens: aggregate.weekTokens,
            fiveHourUsedPercent: rateSnapshot?.primaryUsedPercent,
            fiveHourResetAt: rateSnapshot?.primaryResetAt,
            weekUsedPercent: rateSnapshot?.secondaryUsedPercent,
            weekResetAt: rateSnapshot?.secondaryResetAt,
            lifetimeTokens: lifetimeTokens,
            windowDescription: makeUsageWindowDescription(aggregate: aggregate, rateSnapshot: rateSnapshot),
            burnDescription: Self.burnDescription(for: aggregate.totalTokens),
            accountStatus: rateSnapshot?.planType.map { "local \($0) plan" } ?? "local Codex CLI telemetry"
        )

        let account = AccountSnapshot(
            provider: provider,
            accountLabel: Self.workspaceName(from: latestThread.cwd),
            planLabel: rateSnapshot?.planType.map { "Codex \($0.capitalized)" } ?? "Codex local CLI",
            billingStatus: makeBillingStatus(aggregate: aggregate, rateSnapshot: rateSnapshot)
        )

        let recentActivity = recentThreads.map { thread in
            RecentActivityItem(
                id: "codex:thread:\(thread.id)",
                provider: provider,
                title: Self.compactTitle(thread.title),
                detail: "\(Self.workspaceName(from: thread.cwd)) • \(AppSnapshotFormatter.compactTokenCount(thread.tokensUsed)) tokens",
                occurredAt: thread.updatedAt,
                sourceDescription: "Codex local state"
            )
        }

        return ProviderSnapshotBundle(
            usage: usage,
            account: account,
            recentActivity: recentActivity,
            issues: []
        )
        #else
        throw LocalProviderSnapshotError.invalidSource("SQLite3 is unavailable in this build")
        #endif
    }

    #if canImport(SQLite3)
    private func loadRecentThreads(limit: Int) throws -> [CodexThread] {
        try withDatabase { database in
            let query = """
            SELECT id, rollout_path, updated_at, cwd, title, tokens_used
            FROM threads
            WHERE archived = 0
            ORDER BY updated_at DESC, id DESC
            LIMIT ?;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
                throw LocalProviderSnapshotError.unreadableSource("Failed to prepare Codex thread query")
            }

            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int(statement, 1, Int32(limit))

            var threads: [CodexThread] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Self.stringValue(from: statement, column: 0)
                let rolloutPath = Self.stringValue(from: statement, column: 1)
                let updatedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2)))
                let cwd = Self.stringValue(from: statement, column: 3)
                let title = Self.stringValue(from: statement, column: 4)
                let tokensUsed = Int(sqlite3_column_int64(statement, 5))

                threads.append(
                    CodexThread(
                        id: id,
                        rolloutPath: rolloutPath,
                        updatedAt: updatedAt,
                        cwd: cwd,
                        title: title,
                        tokensUsed: tokensUsed
                    )
                )
            }

            return threads
        }
    }

    private func loadLifetimeTokens() throws -> Int {
        try withDatabase { database in
            let query = "SELECT COALESCE(SUM(tokens_used), 0) FROM threads;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
                throw LocalProviderSnapshotError.unreadableSource("Failed to prepare Codex lifetime token query")
            }
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }

    private func loadTodayAggregate(now: Date) throws -> CodexTodayAggregate {
        let startOfDay = Calendar.current.startOfDay(for: now)
        let fiveHourBoundary = now.addingTimeInterval(-(5 * 60 * 60))
        let weekBoundary = now.addingTimeInterval(-(7 * 24 * 60 * 60))
        let threads = try loadThreadsUpdatedSince(boundary: weekBoundary)

        var totalTokens = 0
        var todayInputTokens = 0
        var todayOutputTokens = 0
        var fiveHourTokens = 0
        var weekTokens = 0
        var threadCount = 0

        for thread in threads {
            guard let summary = try dailyTokenSummary(
                from: thread.rolloutPath,
                startOfDay: startOfDay,
                fiveHourBoundary: fiveHourBoundary,
                weekBoundary: weekBoundary
            ) else {
                continue
            }

            totalTokens += summary.todayTokens
            todayInputTokens += summary.todayInputTokens
            todayOutputTokens += summary.todayOutputTokens
            fiveHourTokens += summary.fiveHourTokens
            weekTokens += summary.weekTokens

            if summary.hadActivityToday {
                threadCount += 1
            }
        }

        return CodexTodayAggregate(
            totalTokens: totalTokens,
            todayInputTokens: todayInputTokens,
            todayOutputTokens: todayOutputTokens,
            fiveHourTokens: fiveHourTokens,
            weekTokens: weekTokens,
            threadCount: threadCount
        )
    }

    private func loadThreadsUpdatedSince(boundary: Date) throws -> [CodexThread] {
        try withDatabase { database in
            let query = """
            SELECT id, rollout_path, updated_at, cwd, title, tokens_used
            FROM threads
            WHERE archived = 0
              AND updated_at >= ?
            ORDER BY updated_at DESC, id DESC;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
                throw LocalProviderSnapshotError.unreadableSource("Failed to prepare Codex daily thread query")
            }

            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, sqlite3_int64(boundary.timeIntervalSince1970))

            var threads: [CodexThread] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Self.stringValue(from: statement, column: 0)
                let rolloutPath = Self.stringValue(from: statement, column: 1)
                let updatedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 2)))
                let cwd = Self.stringValue(from: statement, column: 3)
                let title = Self.stringValue(from: statement, column: 4)
                let tokensUsed = Int(sqlite3_column_int64(statement, 5))

                threads.append(
                    CodexThread(
                        id: id,
                        rolloutPath: rolloutPath,
                        updatedAt: updatedAt,
                        cwd: cwd,
                        title: title,
                        tokensUsed: tokensUsed
                    )
                )
            }

            return threads
        }
    }

    private func dailyTokenSummary(
        from rolloutPath: String,
        startOfDay: Date,
        fiveHourBoundary: Date,
        weekBoundary: Date
    ) throws -> CodexDailyTokenSummary? {
        let url = URL(fileURLWithPath: rolloutPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LocalProviderSnapshotError.missingSource("Codex rollout transcript is missing at \(rolloutPath)")
        }

        let contents = try String(contentsOf: url, encoding: .utf8)
        var lastTotalBeforeDay: Int?
        var latestTotalToday: Int?
        var lastInputBeforeDay: Int?
        var latestInputToday: Int?
        var lastOutputBeforeDay: Int?
        var latestOutputToday: Int?
        var lastTotalBeforeFiveHour: Int?
        var latestTotalFiveHour: Int?
        var lastTotalBeforeWeek: Int?
        var latestTotalWeek: Int?

        for line in contents.split(whereSeparator: \.isNewline) {
            guard let object = Self.jsonObject(from: line),
                  let timestampValue = object["timestamp"] as? String,
                  let timestamp = Self.rolloutTimestamp(from: timestampValue),
                  let type = object["type"] as? String,
                  type == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  let payloadType = payload["type"] as? String,
                  payloadType == "token_count",
                  let info = payload["info"] as? [String: Any],
                  let totalTokenUsage = info["total_token_usage"] as? [String: Any],
                  let inputTokens = Self.intValue(totalTokenUsage["input_tokens"]),
                  let cachedInputTokens = Self.intValue(totalTokenUsage["cached_input_tokens"]),
                  let outputTokens = Self.intValue(totalTokenUsage["output_tokens"]),
                  let reasoningOutputTokens = Self.intValue(totalTokenUsage["reasoning_output_tokens"]),
                  let totalTokens = Self.intValue(totalTokenUsage["total_tokens"]) else {
                continue
            }

            let effectiveInputTokens = inputTokens + cachedInputTokens
            let effectiveOutputTokens = outputTokens + reasoningOutputTokens

            if timestamp < weekBoundary {
                lastTotalBeforeWeek = totalTokens
            } else {
                latestTotalWeek = totalTokens
            }

            if timestamp < fiveHourBoundary {
                lastTotalBeforeFiveHour = totalTokens
            } else {
                latestTotalFiveHour = totalTokens
            }

            if timestamp < startOfDay {
                lastTotalBeforeDay = totalTokens
                lastInputBeforeDay = effectiveInputTokens
                lastOutputBeforeDay = effectiveOutputTokens
                continue
            }

            latestTotalToday = totalTokens
            latestInputToday = effectiveInputTokens
            latestOutputToday = effectiveOutputTokens
        }

        guard latestTotalToday != nil || latestTotalFiveHour != nil || latestTotalWeek != nil else {
            return nil
        }

        let dayBaseline = lastTotalBeforeDay ?? 0
        let fiveHourBaseline = lastTotalBeforeFiveHour ?? 0
        let weekBaseline = lastTotalBeforeWeek ?? 0
        return CodexDailyTokenSummary(
            todayTokens: max(0, (latestTotalToday ?? 0) - dayBaseline),
            todayInputTokens: max(0, (latestInputToday ?? 0) - (lastInputBeforeDay ?? 0)),
            todayOutputTokens: max(0, (latestOutputToday ?? 0) - (lastOutputBeforeDay ?? 0)),
            fiveHourTokens: max(0, (latestTotalFiveHour ?? 0) - fiveHourBaseline),
            weekTokens: max(0, (latestTotalWeek ?? 0) - weekBaseline),
            hadActivityToday: latestTotalToday != nil
        )
    }

    private func loadRateSnapshot(from rolloutPath: String) throws -> CodexRateSnapshot {
        let url = URL(fileURLWithPath: rolloutPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LocalProviderSnapshotError.missingSource("Codex rollout transcript is missing at \(rolloutPath)")
        }

        let contents = try String(contentsOf: url, encoding: .utf8)
        var latestPayload: [String: Any]?
        var latestPayloadTimestamp: Date?

        for line in contents.split(whereSeparator: \.isNewline) {
            guard let object = Self.jsonObject(from: line),
                  let timestampValue = object["timestamp"] as? String,
                  let timestamp = Self.rolloutTimestamp(from: timestampValue),
                  let type = object["type"] as? String,
                  type == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  let payloadType = payload["type"] as? String,
                  payloadType == "token_count" else {
                continue
            }

            latestPayload = payload
            latestPayloadTimestamp = timestamp
        }

        guard let latestPayload else {
            throw LocalProviderSnapshotError.invalidSource("Codex rollout transcript does not contain a token snapshot")
        }

        let rateLimits = latestPayload["rate_limits"] as? [String: Any]
        let primary = rateLimits?["primary"] as? [String: Any]
        let secondary = rateLimits?["secondary"] as? [String: Any]

        return CodexRateSnapshot(
            planType: rateLimits?["plan_type"] as? String,
            primaryUsedPercent: Self.doubleValue(primary?["used_percent"]),
            primaryWindowMinutes: Self.intValue(primary?["window_minutes"]),
            primaryResetAt: Self.resetDate(
                from: Self.intValue(primary?["resets_in_seconds"]),
                referenceDate: latestPayloadTimestamp
            ),
            secondaryUsedPercent: Self.doubleValue(secondary?["used_percent"]),
            secondaryWindowMinutes: Self.intValue(secondary?["window_minutes"]),
            secondaryResetAt: Self.resetDate(
                from: Self.intValue(secondary?["resets_in_seconds"]),
                referenceDate: latestPayloadTimestamp
            )
        )
    }

    private func withDatabase<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        guard FileManager.default.fileExists(atPath: stateDatabaseURL.path) else {
            throw LocalProviderSnapshotError.missingSource("Codex local state database is missing in ~/.codex")
        }

        let databaseSnapshot = try makeDatabaseSnapshot()
        defer { try? FileManager.default.removeItem(at: databaseSnapshot.directoryURL) }

        var database: OpaquePointer?
        // Use READWRITE (not READONLY) on the temp copy: WAL mode requires creating the .shm
        // shared-memory file, which fails in read-only mode when .shm isn't pre-seeded.
        guard sqlite3_open_v2(databaseSnapshot.databaseURL.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let database else {
            throw LocalProviderSnapshotError.unreadableSource("Failed to open Codex local state database")
        }

        defer { sqlite3_close(database) }
        return try body(database)
    }

    private func makeDatabaseSnapshot() throws -> CodexDatabaseSnapshot {
        let fileManager = FileManager.default
        let snapshotDirectoryURL = fileManager.temporaryDirectory
            .appending(path: "retoken-codex-\(UUID().uuidString)", directoryHint: .isDirectory)
        let snapshotDatabaseURL = snapshotDirectoryURL.appending(path: stateDatabaseURL.lastPathComponent)

        try fileManager.createDirectory(at: snapshotDirectoryURL, withIntermediateDirectories: true)
        try fileManager.copyItem(at: stateDatabaseURL, to: snapshotDatabaseURL)

        for suffix in ["-wal", "-shm"] {
            let sourceURL = URL(fileURLWithPath: stateDatabaseURL.path + suffix)
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                continue
            }

            let destinationURL = URL(fileURLWithPath: snapshotDatabaseURL.path + suffix)
            try? fileManager.copyItem(at: sourceURL, to: destinationURL)
        }

        return CodexDatabaseSnapshot(
            directoryURL: snapshotDirectoryURL,
            databaseURL: snapshotDatabaseURL
        )
    }

    private func makeUsageWindowDescription(
        aggregate: CodexTodayAggregate,
        rateSnapshot: CodexRateSnapshot?
    ) -> String {
        let base = "\(aggregate.threadCount) threads today"

        guard let rateSnapshot else {
            return base
        }

        let rateText = [
            rateSnapshot.primaryWindowMinutes.map { "\(Self.windowLabel(minutes: $0)) \(Self.percentString(rateSnapshot.primaryUsedPercent))" },
            rateSnapshot.secondaryWindowMinutes.map { "\(Self.windowLabel(minutes: $0)) \(Self.percentString(rateSnapshot.secondaryUsedPercent))" }
        ]
            .compactMap { $0 }
            .joined(separator: " • ")

        return rateText.isEmpty ? base : "\(base) • \(rateText)"
    }

    private func makeBillingStatus(
        aggregate: CodexTodayAggregate,
        rateSnapshot: CodexRateSnapshot?
    ) -> String {
        let base = "\(AppSnapshotFormatter.compactTokenCount(aggregate.totalTokens)) tokens today"

        guard let rateSnapshot else {
            return base
        }

        let rateText = [
            rateSnapshot.planType?.capitalized,
            rateSnapshot.primaryWindowMinutes.map { "\(Self.windowLabel(minutes: $0)) \(Self.percentString(rateSnapshot.primaryUsedPercent))" },
            rateSnapshot.secondaryWindowMinutes.map { "\(Self.windowLabel(minutes: $0)) \(Self.percentString(rateSnapshot.secondaryUsedPercent))" }
        ]
            .compactMap { $0 }
            .joined(separator: " • ")

        return rateText.isEmpty ? base : "\(rateText) • \(base)"
    }

    private static func stringValue(from statement: OpaquePointer?, column: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, column) else {
            return ""
        }

        return String(cString: pointer)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }

        if let value = value as? Int {
            return Double(value)
        }

        if let value = value as? NSNumber {
            return value.doubleValue
        }

        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }

        if let value = value as? NSNumber {
            return value.intValue
        }

        return nil
    }
    #endif

    private static func workspaceName(from path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
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

    private static func burnDescription(for tokens: Int) -> String {
        switch tokens {
        case 50_000_000...:
            return "furnace"
        case 1_000_000...:
            return "hot"
        case 1...:
            return "steady"
        default:
            return "idle"
        }
    }

    private static func windowLabel(minutes: Int) -> String {
        if minutes.isMultiple(of: 10_080) {
            return "\(minutes / 10_080)w"
        }

        if minutes.isMultiple(of: 1_440) {
            return "\(minutes / 1_440)d"
        }

        if minutes.isMultiple(of: 60) {
            return "\(minutes / 60)h"
        }

        return "\(minutes)m"
    }

    private static func percentString(_ value: Double?) -> String {
        guard let value else {
            return "?"
        }

        return String(format: "%.0f%%", value)
    }

    private static func resetDate(from seconds: Int?, referenceDate: Date?) -> Date? {
        guard let seconds, let referenceDate else {
            return nil
        }

        return referenceDate.addingTimeInterval(TimeInterval(seconds))
    }

    private static func jsonObject(from line: Substring) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return object
    }

    private static func rolloutTimestamp(from value: String) -> Date? {
        if let date = rolloutFractionalSecondFormatter.date(from: value) {
            return date
        }

        return rolloutFormatter.date(from: value)
    }

    private static let rolloutFractionalSecondFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let rolloutFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

private struct CodexThread {
    let id: String
    let rolloutPath: String
    let updatedAt: Date
    let cwd: String
    let title: String
    let tokensUsed: Int
}

private struct CodexTodayAggregate {
    let totalTokens: Int
    let todayInputTokens: Int
    let todayOutputTokens: Int
    let fiveHourTokens: Int
    let weekTokens: Int
    let threadCount: Int
}

private struct CodexDailyTokenSummary {
    let todayTokens: Int
    let todayInputTokens: Int
    let todayOutputTokens: Int
    let fiveHourTokens: Int
    let weekTokens: Int
    let hadActivityToday: Bool
}

private struct CodexRateSnapshot {
    let planType: String?
    let primaryUsedPercent: Double?
    let primaryWindowMinutes: Int?
    let primaryResetAt: Date?
    let secondaryUsedPercent: Double?
    let secondaryWindowMinutes: Int?
    let secondaryResetAt: Date?
}

private struct CodexDatabaseSnapshot {
    let directoryURL: URL
    let databaseURL: URL
}
