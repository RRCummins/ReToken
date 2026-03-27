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
        let rateSnapshot = recentThreads.lazy.compactMap { try? loadRateSnapshot(from: $0.rolloutPath) }.first

        let usage = ProviderUsageSnapshot(
            provider: provider,
            todayTokens: aggregate.totalTokens,
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

    private func loadTodayAggregate(now: Date) throws -> CodexTodayAggregate {
        try withDatabase { database in
            let query = """
            SELECT COALESCE(SUM(tokens_used), 0), COUNT(*)
            FROM threads
            WHERE archived = 0
              AND date(updated_at, 'unixepoch', 'localtime') = date(?, 'unixepoch', 'localtime');
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
                throw LocalProviderSnapshotError.unreadableSource("Failed to prepare Codex daily aggregate query")
            }

            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, sqlite3_int64(now.timeIntervalSince1970))

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return CodexTodayAggregate(totalTokens: 0, threadCount: 0)
            }

            return CodexTodayAggregate(
                totalTokens: Int(sqlite3_column_int64(statement, 0)),
                threadCount: Int(sqlite3_column_int64(statement, 1))
            )
        }
    }

    private func loadRateSnapshot(from rolloutPath: String) throws -> CodexRateSnapshot {
        let url = URL(fileURLWithPath: rolloutPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LocalProviderSnapshotError.missingSource("Codex rollout transcript is missing at \(rolloutPath)")
        }

        let contents = try String(contentsOf: url, encoding: .utf8)
        var latestPayload: [String: Any]?

        for line in contents.split(whereSeparator: \.isNewline) {
            guard let data = line.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = object["type"] as? String,
                  type == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  let payloadType = payload["type"] as? String,
                  payloadType == "token_count" else {
                continue
            }

            latestPayload = payload
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
            secondaryUsedPercent: Self.doubleValue(secondary?["used_percent"]),
            secondaryWindowMinutes: Self.intValue(secondary?["window_minutes"])
        )
    }

    private func withDatabase<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        guard FileManager.default.fileExists(atPath: stateDatabaseURL.path) else {
            throw LocalProviderSnapshotError.missingSource("Codex local state database is missing in ~/.codex")
        }

        var database: OpaquePointer?
        guard sqlite3_open_v2(stateDatabaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let database else {
            throw LocalProviderSnapshotError.unreadableSource("Failed to open Codex local state database")
        }

        defer { sqlite3_close(database) }
        return try body(database)
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
    let threadCount: Int
}

private struct CodexRateSnapshot {
    let planType: String?
    let primaryUsedPercent: Double?
    let primaryWindowMinutes: Int?
    let secondaryUsedPercent: Double?
    let secondaryWindowMinutes: Int?
}
