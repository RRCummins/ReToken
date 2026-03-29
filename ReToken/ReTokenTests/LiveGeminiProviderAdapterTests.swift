import Foundation
import XCTest
@testable import ReToken

@MainActor
final class LiveGeminiProviderAdapterTests: XCTestCase {
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

    func testFetchSnapshotBuildsUsageWindowsAndRecentActivityFromLocalChats() async throws {
        let now = Date(timeIntervalSince1970: 1_774_188_000)
        let chatRootURL = temporaryDirectoryURL.appending(path: "tmp", directoryHint: .isDirectory)
        let historyRootURL = temporaryDirectoryURL.appending(path: "history", directoryHint: .isDirectory)
        let workspaceDirectory = chatRootURL.appending(path: "retoken", directoryHint: .isDirectory)
        let chatsDirectory = workspaceDirectory.appending(path: "chats", directoryHint: .isDirectory)
        let historyWorkspaceDirectory = historyRootURL.appending(path: "retoken", directoryHint: .isDirectory)
        let sessionURL = chatsDirectory.appending(path: "session-2026-03-29T14-26-demo.json")

        try FileManager.default.createDirectory(at: chatsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: historyWorkspaceDirectory, withIntermediateDirectories: true)

        try "/Users/test/Developer/ReToken\n".write(
            to: historyWorkspaceDirectory.appending(path: ".project_root"),
            atomically: true,
            encoding: .utf8
        )

        let fiveMinutesAgo = Self.iso8601String(from: now.addingTimeInterval(-(5 * 60)))
        let twoHoursAgo = Self.iso8601String(from: now.addingTimeInterval(-(2 * 60 * 60)))
        let yesterday = Self.iso8601String(from: now.addingTimeInterval(-(26 * 60 * 60)))

        try """
        {
          "sessionId": "session-1",
          "messages": [
            {
              "id": "user-1",
              "timestamp": "\(twoHoursAgo)",
              "type": "user",
              "content": [{ "text": "Help with ReToken" }]
            },
            {
              "id": "gemini-1",
              "timestamp": "\(twoHoursAgo)",
              "type": "gemini",
              "content": "Let’s wire the menu bar stats.",
              "tokens": {
                "input": 1200,
                "output": 300,
                "cached": 50,
                "thoughts": 25,
                "tool": 0,
                "total": 1575
              },
              "model": "gemini-3-flash-preview"
            },
            {
              "id": "gemini-2",
              "timestamp": "\(fiveMinutesAgo)",
              "type": "gemini",
              "content": "Hour-by-hour graph is ready.",
              "tokens": {
                "input": 2400,
                "output": 600,
                "cached": 100,
                "thoughts": 100,
                "tool": 0,
                "total": 3200
              },
              "model": "gemini-3-flash-preview"
            },
            {
              "id": "gemini-3",
              "timestamp": "\(yesterday)",
              "type": "gemini",
              "content": "Older weekly response.",
              "tokens": {
                "total": 2100
              },
              "model": "gemini-3-pro"
            }
          ]
        }
        """.write(to: sessionURL, atomically: true, encoding: .utf8)

        let adapter = LiveGeminiProviderAdapter(chatRootURL: chatRootURL, historyRootURL: historyRootURL)
        let bundle = await adapter.fetchSnapshot(context: ProviderFetchContext(refreshCount: 1, now: now))

        XCTAssertEqual(bundle.usage.provider, .gemini)
        XCTAssertTrue(bundle.usage.isVisible)
        XCTAssertEqual(bundle.usage.todayTokens, 4_775)
        XCTAssertEqual(bundle.usage.todayInputTokens, 3_750)
        XCTAssertEqual(bundle.usage.todayOutputTokens, 1_025)
        XCTAssertEqual(bundle.usage.fiveHourTokens, 4_775)
        XCTAssertEqual(bundle.usage.weekTokens, 6_875)
        XCTAssertEqual(bundle.usage.lifetimeTokens, 6_875)
        XCTAssertEqual(bundle.usage.windowDescription, "3 responses • 1 sessions tracked")
        XCTAssertEqual(bundle.account.accountLabel, "Gemini 3 Flash Preview")
        XCTAssertEqual(bundle.account.planLabel, "Gemini local CLI")
        XCTAssertEqual(bundle.account.billingStatus, "3 responses • 1 workspaces")
        XCTAssertEqual(bundle.recentActivity.count, 1)
        XCTAssertEqual(bundle.recentActivity.first?.provider, .gemini)
        XCTAssertEqual(bundle.recentActivity.first?.detail, "ReToken • 6.9K tokens")
        XCTAssertTrue(bundle.issues.isEmpty)
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
