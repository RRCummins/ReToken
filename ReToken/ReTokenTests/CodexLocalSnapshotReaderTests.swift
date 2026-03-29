import Foundation
import XCTest
@testable import ReToken
#if canImport(SQLite3)
import SQLite3
#endif

final class CodexLocalSnapshotReaderTests: XCTestCase {
    private var temporaryDirectoryURL: URL!

    override func setUpWithError() throws {
        temporaryDirectoryURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectoryURL {
            try? FileManager.default.removeItem(at: temporaryDirectoryURL)
        }
    }

    func testReadSnapshotBuildsRecentActivityAndDailyTotals() throws {
        #if canImport(SQLite3)
        let calendar = Calendar.current
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 5, day: 18, hour: 12, minute: 0))
        )
        let startOfDay = calendar.startOfDay(for: now)
        let databaseURL = temporaryDirectoryURL.appending(path: "state.sqlite")
        let rolloutOneURL = temporaryDirectoryURL.appending(path: "rollout-one.jsonl")
        let rolloutTwoURL = temporaryDirectoryURL.appending(path: "rollout-two.jsonl")
        let yesterdayRolloutURL = temporaryDirectoryURL.appending(path: "yesterday-rollout.jsonl")
        let beforeToday = Self.iso8601String(from: startOfDay.addingTimeInterval(-60))
        let shortlyAfterStartOfDay = Self.iso8601String(from: startOfDay.addingTimeInterval(180))
        let sessionOneStart = Self.iso8601String(from: startOfDay.addingTimeInterval(-120))
        let sessionTwoStart = Self.iso8601String(from: startOfDay.addingTimeInterval(60))
        let sessionTwoToken = Self.iso8601String(from: now.addingTimeInterval(-(60 * 60)))
        let yesterdayToken = Self.iso8601String(from: startOfDay.addingTimeInterval(-15 * 60 * 60))
        let oldSessionStart = Self.iso8601String(from: startOfDay.addingTimeInterval(-36 * 60 * 60))

        try write(
            """
            {"timestamp":"\(sessionOneStart)","type":"session_meta","payload":{"id":"thread-1","cwd":"/Users/test/Developer/ReToken","model_provider":"openai","source":"cli","timestamp":"\(sessionOneStart)","base_instructions":"","cli_version":"1.0.0","originator":"user"}}
            not-json-at-all
            {"timestamp":"\(beforeToday)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":700,"cached_input_tokens":0,"output_tokens":300,"reasoning_output_tokens":0,"total_tokens":1000},"last_token_usage":{"input_tokens":700,"cached_input_tokens":0,"output_tokens":300,"reasoning_output_tokens":0,"total_tokens":1000},"model_context_window":258400},"rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":8.0,"window_minutes":300,"resets_at":1780000000},"secondary":{"used_percent":40.0,"window_minutes":10080,"resets_at":1780500000},"credits":null,"plan_type":"plus"}}}
            {"timestamp":"\(shortlyAfterStartOfDay)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":2000,"output_tokens":500,"reasoning_output_tokens":0,"total_tokens":3500},"last_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":50,"reasoning_output_tokens":0,"total_tokens":150},"model_context_window":258400},"rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":12.0,"window_minutes":300,"resets_at":1780000000},"secondary":{"used_percent":64.0,"window_minutes":10080,"resets_at":1780500000},"credits":null,"plan_type":"plus"}}}
            """,
            to: rolloutOneURL
        )

        try write(
            """
            {"timestamp":"\(sessionTwoStart)","type":"session_meta","payload":{"id":"thread-2","cwd":"/Users/test/Developer/SubFramed","model_provider":"openai","source":"cli","timestamp":"\(sessionTwoStart)","base_instructions":"","cli_version":"1.0.0","originator":"user"}}
            {"timestamp":"\(sessionTwoToken)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":500,"cached_input_tokens":0,"output_tokens":300,"reasoning_output_tokens":0,"total_tokens":800},"last_token_usage":{"input_tokens":500,"cached_input_tokens":0,"output_tokens":300,"reasoning_output_tokens":0,"total_tokens":800},"model_context_window":258400},"rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":12.0,"window_minutes":300,"resets_at":1780000000},"secondary":{"used_percent":64.0,"window_minutes":10080,"resets_at":1780500000},"credits":null,"plan_type":"plus"}}}
            """,
            to: rolloutTwoURL
        )

        try write(
            """
            {"timestamp":"\(oldSessionStart)","type":"session_meta","payload":{"id":"thread-3","cwd":"/Users/test/Developer/OldProject","model_provider":"openai","source":"cli","timestamp":"\(oldSessionStart)","base_instructions":"","cli_version":"1.0.0","originator":"user"}}
            {"timestamp":"\(yesterdayToken)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10000,"cached_input_tokens":0,"output_tokens":2000,"reasoning_output_tokens":0,"total_tokens":12000},"last_token_usage":{"input_tokens":1000,"cached_input_tokens":0,"output_tokens":200,"reasoning_output_tokens":0,"total_tokens":1200},"model_context_window":258400},"rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":20.0,"window_minutes":300,"resets_at":1780000000},"secondary":{"used_percent":70.0,"window_minutes":10080,"resets_at":1780500000},"credits":null,"plan_type":"plus"}}}
            """,
            to: yesterdayRolloutURL
        )

        try createStateDatabase(
            at: databaseURL,
            rows: [
                ThreadFixture(
                    id: "thread-1",
                    rolloutPath: rolloutOneURL.path,
                    updatedAt: Int(now.timeIntervalSince1970),
                    cwd: "/Users/test/Developer/ReToken",
                    title: "Build local Codex ingestion",
                    tokensUsed: 12_500,
                    archived: 0
                ),
                ThreadFixture(
                    id: "thread-2",
                    rolloutPath: rolloutTwoURL.path,
                    updatedAt: Int(now.addingTimeInterval(-600).timeIntervalSince1970),
                    cwd: "/Users/test/Developer/SubFramed",
                    title: "Finish another app",
                    tokensUsed: 8_000,
                    archived: 0
                ),
                ThreadFixture(
                    id: "thread-3",
                    rolloutPath: yesterdayRolloutURL.path,
                    updatedAt: Int(now.addingTimeInterval(-90_000).timeIntervalSince1970),
                    cwd: "/Users/test/Developer/OldProject",
                    title: "Yesterday work",
                    tokensUsed: 99_000,
                    archived: 0
                )
            ]
        )

        let reader = CodexLocalSnapshotReader(stateDatabaseURL: databaseURL)
        let snapshot = try reader.readSnapshot(now: now)

        XCTAssertEqual(snapshot.usage.todayTokens, 3_300)
        XCTAssertEqual(snapshot.usage.todayInputTokens, 2_800)
        XCTAssertEqual(snapshot.usage.todayOutputTokens, 500)
        XCTAssertEqual(snapshot.usage.fiveHourTokens, 800)
        XCTAssertEqual(snapshot.usage.weekTokens, 16_300)
        XCTAssertEqual(snapshot.usage.windowDescription, "2 threads today • 5h 12% • 1w 64%")
        XCTAssertEqual(snapshot.account.accountLabel, "ReToken")
        XCTAssertEqual(snapshot.account.planLabel, "Codex Plus")
        XCTAssertEqual(snapshot.account.billingStatus, "Plus • 5h 12% • 1w 64% • 3.3K tokens today")
        XCTAssertEqual(snapshot.recentActivity.count, 3)
        XCTAssertEqual(snapshot.recentActivity.first?.id, "codex:thread:thread-1")
        XCTAssertEqual(snapshot.recentActivity.first?.title, "Build local Codex ingestion")
        XCTAssertEqual(snapshot.recentActivity.first?.detail, "ReToken • 12.5K tokens")
        XCTAssertEqual(snapshot.recentActivity.first?.sourceDescription, "Codex local state")
        XCTAssertEqual(snapshot.issues.count, 0)
        #else
        throw XCTSkip("SQLite3 is unavailable in this environment")
        #endif
    }

    #if canImport(SQLite3)
    private func createStateDatabase(at url: URL, rows: [ThreadFixture]) throws {
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &database), SQLITE_OK)
        guard let database else {
            XCTFail("Failed to open sqlite database")
            return
        }

        defer { sqlite3_close(database) }

        XCTAssertEqual(
            sqlite3_exec(
                database,
                """
                CREATE TABLE threads (
                    id TEXT PRIMARY KEY,
                    rollout_path TEXT NOT NULL,
                    updated_at INTEGER NOT NULL,
                    cwd TEXT NOT NULL,
                    title TEXT NOT NULL,
                    tokens_used INTEGER NOT NULL,
                    archived INTEGER NOT NULL DEFAULT 0
                );
                """,
                nil,
                nil,
                nil
            ),
            SQLITE_OK
        )

        let insertSQL = """
        INSERT INTO threads (id, rollout_path, updated_at, cwd, title, tokens_used, archived)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(database, insertSQL, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }

        for row in rows {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_text(statement, 1, row.id, -1, sqliteTransientDestructor)
            sqlite3_bind_text(statement, 2, row.rolloutPath, -1, sqliteTransientDestructor)
            sqlite3_bind_int64(statement, 3, sqlite3_int64(row.updatedAt))
            sqlite3_bind_text(statement, 4, row.cwd, -1, sqliteTransientDestructor)
            sqlite3_bind_text(statement, 5, row.title, -1, sqliteTransientDestructor)
            sqlite3_bind_int64(statement, 6, sqlite3_int64(row.tokensUsed))
            sqlite3_bind_int(statement, 7, Int32(row.archived))
            XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
        }
    }
    #endif

    private func write(_ value: String, to url: URL) throws {
        try value.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func iso8601String(from date: Date) -> String {
        rolloutFormatter.string(from: date)
    }
}

#if canImport(SQLite3)
private struct ThreadFixture {
    let id: String
    let rolloutPath: String
    let updatedAt: Int
    let cwd: String
    let title: String
    let tokensUsed: Int
    let archived: Int
}

private let sqliteTransientDestructor = unsafeBitCast(
    -1,
    to: sqlite3_destructor_type.self
)

private let rolloutFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()
#endif
