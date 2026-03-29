import Foundation
import XCTest
@testable import ReToken

final class ClaudeLocalSnapshotReaderTests: XCTestCase {
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

    func testReadSnapshotBuildsUsageAndRecentActivityFromLocalFiles() throws {
        let now = Date(timeIntervalSince1970: 1_780_012_800) // 2026-05-18 00:00:00 UTC
        let todayKey = dayString(for: now)
        let historyURL = temporaryDirectoryURL.appending(path: "history.jsonl")
        let statsURL = temporaryDirectoryURL.appending(path: "stats-cache.json")

        try write(
            """
            {"display":"First Claude prompt","project":"/Users/test/Developer/ReToken","sessionId":"session-1","timestamp":1780012000000}
            {"display":"Latest Claude prompt","project":"/Users/test/Developer/ReToken","sessionId":"session-1","timestamp":1780012600000}
            {"display":"Other workspace prompt","project":"/Users/test/Developer/SubFramed","sessionId":"session-2","timestamp":1780011000000}
            """,
            to: historyURL
        )

        try write(
            """
            {
              "dailyActivity": [
                { "date": "\(todayKey)", "messageCount": 12, "sessionCount": 2, "toolCallCount": 4 }
              ],
              "dailyModelTokens": [
                { "date": "\(todayKey)", "tokensByModel": { "claude-opus-4-6": 42000, "claude-sonnet-4": 8000 } }
              ],
              "modelUsage": {
                "claude-opus-4-6": {
                  "inputTokens": 1000,
                  "outputTokens": 2000,
                  "cacheReadInputTokens": 3000,
                  "cacheCreationInputTokens": 4000
                }
              },
              "totalMessages": 88,
              "totalSessions": 7,
              "lastComputedDate": "\(todayKey)"
            }
            """,
            to: statsURL
        )

        let reader = ClaudeLocalSnapshotReader(historyURL: historyURL, statsCacheURL: statsURL)
        let snapshot = try reader.readSnapshot(now: now)

        XCTAssertEqual(snapshot.usage.todayTokens, 50_000)
        XCTAssertEqual(snapshot.usage.todayInputTokens, nil)
        XCTAssertEqual(snapshot.usage.todayOutputTokens, nil)
        XCTAssertEqual(snapshot.usage.windowDescription, "12 msgs • 2 sessions today")
        XCTAssertEqual(snapshot.usage.accountStatus, "local Claude CLI stats")
        XCTAssertEqual(snapshot.account.accountLabel, "Claude Opus 4 6")
        XCTAssertEqual(snapshot.account.billingStatus, "88 messages • 7 sessions total")
        XCTAssertEqual(snapshot.issues.count, 0)
        XCTAssertEqual(snapshot.recentActivity.count, 2)
        XCTAssertEqual(snapshot.recentActivity.first?.id, "claude:session:session-1")
        XCTAssertEqual(snapshot.recentActivity.first?.title, "Latest Claude prompt")
        XCTAssertEqual(snapshot.recentActivity.first?.detail, "ReToken")
        XCTAssertEqual(snapshot.recentActivity.first?.sourceDescription, "Claude local history")
    }

    func testReadSnapshotFlagsStaleStatsCache() throws {
        let now = Date(timeIntervalSince1970: 1_780_012_800)
        let staleDayKey = dayString(for: now.addingTimeInterval(-86_400))
        let historyURL = temporaryDirectoryURL.appending(path: "history.jsonl")
        let statsURL = temporaryDirectoryURL.appending(path: "stats-cache.json")

        try write(
            """
            {"display":"Prompt","project":"/Users/test/Developer/ReToken","sessionId":"session-1","timestamp":1780012600000}
            """,
            to: historyURL
        )

        try write(
            """
            {
              "dailyActivity": [],
              "dailyModelTokens": [],
              "modelUsage": {},
              "totalMessages": 1,
              "totalSessions": 1,
              "lastComputedDate": "\(staleDayKey)"
            }
            """,
            to: statsURL
        )

        let reader = ClaudeLocalSnapshotReader(historyURL: historyURL, statsCacheURL: statsURL)
        let snapshot = try reader.readSnapshot(now: now)

        XCTAssertEqual(snapshot.usage.todayTokens, 0)
        XCTAssertEqual(snapshot.issues.map(\.message), ["Local token stats last updated \(staleDayKey)"])
    }

    func testReadSnapshotCapturesInputAndOutputSplitFromProjectLogs() throws {
        let now = Date()
        let historyURL = temporaryDirectoryURL.appending(path: "history.jsonl")
        let statsURL = temporaryDirectoryURL.appending(path: "stats-cache.json")
        let projectsURL = temporaryDirectoryURL.appending(path: "projects", directoryHint: .isDirectory)
        let projectURL = projectsURL.appending(path: "ReToken", directoryHint: .isDirectory)
        let transcriptURL = projectURL.appending(path: "session.jsonl")
        let transcriptTimestamp = iso8601String(for: now.addingTimeInterval(-(60 * 60)))

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try write(
            """
            {"display":"Prompt","project":"/Users/test/Developer/ReToken","sessionId":"session-1","timestamp":1780012600000}
            """,
            to: historyURL
        )
        try write(
            """
            {
              "dailyActivity": [],
              "dailyModelTokens": [],
              "modelUsage": {},
              "totalMessages": 1,
              "totalSessions": 1,
              "lastComputedDate": "2026-05-17"
            }
            """,
            to: statsURL
        )
        try write(
            """
            {"type":"assistant","timestamp":"\(transcriptTimestamp)","message":{"model":"claude-sonnet-4","usage":{"input_tokens":1200,"output_tokens":450,"cache_creation_input_tokens":50,"cache_read_input_tokens":300}}}
            """,
            to: transcriptURL
        )

        let reader = ClaudeLocalSnapshotReader(
            historyURL: historyURL,
            statsCacheURL: statsURL,
            projectsDirectoryURL: projectsURL
        )
        let snapshot = try reader.readSnapshot(now: now)

        XCTAssertEqual(snapshot.usage.todayTokens, 2_000)
        XCTAssertEqual(snapshot.usage.todayInputTokens, 1_550)
        XCTAssertEqual(snapshot.usage.todayOutputTokens, 450)
    }

    private func write(_ value: String, to url: URL) throws {
        try value.write(to: url, atomically: true, encoding: .utf8)
    }

    private func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func iso8601String(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
