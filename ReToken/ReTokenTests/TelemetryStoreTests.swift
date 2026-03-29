import Foundation
import XCTest
@testable import ReToken

final class TelemetryStoreTests: XCTestCase {
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

    func testMergePersistingActivityDeduplicatesStableIdentifiersAndLoadsMergedHistory() {
        let store = TelemetryStore(baseDirectoryURL: temporaryDirectoryURL, maxStoredActivities: 10)
        let baseTime = Date(timeIntervalSince1970: 1_780_012_800)

        let initialItems = [
            SnapshotFixtures.activity(
                id: "claude:session:session-1",
                provider: .claude,
                title: "Claude draft",
                detail: "ReToken",
                occurredAt: baseTime.addingTimeInterval(-600),
                sourceDescription: "Claude local history"
            ),
            SnapshotFixtures.activity(
                id: "codex:thread:thread-1",
                provider: .codex,
                title: "Codex thread",
                detail: "ReToken • 12.5K tokens",
                occurredAt: baseTime.addingTimeInterval(-300),
                sourceDescription: "Codex local state"
            )
        ]

        _ = store.mergePersistingActivity(initialItems, visibleLimit: 10)

        let mergedItems = store.mergePersistingActivity([
            SnapshotFixtures.activity(
                id: "claude:session:session-1",
                provider: .claude,
                title: "Claude draft updated",
                detail: "ReToken",
                occurredAt: baseTime.addingTimeInterval(-60),
                sourceDescription: "Claude local history"
            ),
            SnapshotFixtures.activity(
                id: "codex:thread:thread-2",
                provider: .codex,
                title: "Fresh Codex thread",
                detail: "SubFramed • 8.0K tokens",
                occurredAt: baseTime.addingTimeInterval(-30),
                sourceDescription: "Codex local state"
            )
        ], visibleLimit: 10)

        XCTAssertEqual(mergedItems.map(\.id), [
            "codex:thread:thread-2",
            "claude:session:session-1",
            "codex:thread:thread-1"
        ])
        XCTAssertEqual(mergedItems.first?.title, "Fresh Codex thread")
        XCTAssertEqual(mergedItems[1].title, "Claude draft updated")
        XCTAssertEqual(store.loadRecentActivity(limit: 10).map(\.id), mergedItems.map(\.id))
    }

    func testRecordUsageBuildsTrackingSummaryAcrossProviders() {
        let store = TelemetryStore(baseDirectoryURL: temporaryDirectoryURL, maxStoredActivities: 10)
        let recordedAt = Date(timeIntervalSince1970: 1_780_012_800)
        let snapshot = SnapshotFixtures.snapshot(
            usage: [
                SnapshotFixtures.usage(provider: .claude, todayTokens: 920_000),
                SnapshotFixtures.usage(provider: .codex, todayTokens: 1_240_000)
            ],
            accounts: [
                SnapshotFixtures.account(provider: .claude, accountLabel: "claude@example.com", planLabel: "Max 20x"),
                SnapshotFixtures.account(provider: .codex, accountLabel: "team themrhinos", planLabel: "pay-as-you-go")
            ],
            usageTrackingSummary: .empty,
            lastUpdatedAt: recordedAt,
            mode: .live
        )

        store.recordUsage(snapshot: snapshot)
        let summary = store.loadUsageTrackingSummary()

        XCTAssertEqual(summary.sampleCount, 2)
        XCTAssertEqual(summary.trackedProviderCount, 2)
        XCTAssertEqual(summary.lastRecordedAt, recordedAt)
        XCTAssertEqual(summary.peakProvider, .codex)
        XCTAssertEqual(summary.peakTokens, 1_240_000)
    }

    func testLoadUsageLeaderboardSummaryBuildsRanksAndProviderBests() {
        let store = TelemetryStore(baseDirectoryURL: temporaryDirectoryURL, maxStoredActivities: 10)
        let firstRecordedAt = Date(timeIntervalSince1970: 1_780_012_800)
        let secondRecordedAt = firstRecordedAt.addingTimeInterval(300)

        store.recordUsage(snapshot: SnapshotFixtures.snapshot(
            usage: [
                SnapshotFixtures.usage(provider: .claude, todayTokens: 700_000),
                SnapshotFixtures.usage(provider: .codex, todayTokens: 500_000)
            ],
            lastUpdatedAt: firstRecordedAt,
            mode: .live
        ))

        store.recordUsage(snapshot: SnapshotFixtures.snapshot(
            usage: [
                SnapshotFixtures.usage(provider: .claude, todayTokens: 930_000),
                SnapshotFixtures.usage(provider: .codex, todayTokens: 610_000),
                SnapshotFixtures.usage(provider: .gemini, todayTokens: 280_000)
            ],
            lastUpdatedAt: secondRecordedAt,
            mode: .live
        ))

        let leaderboard = store.loadUsageLeaderboardSummary()

        XCTAssertEqual(leaderboard.currentRunRank, 1)
        XCTAssertEqual(leaderboard.bestRecordedTotal, 1_820_000)
        XCTAssertEqual(leaderboard.bestRecordedAt, secondRecordedAt)
        XCTAssertEqual(leaderboard.mostTrackedProvider, .claude)
        XCTAssertEqual(leaderboard.mostTrackedSampleCount, 2)
        XCTAssertEqual(leaderboard.championEntry?.provider, .claude)
        XCTAssertEqual(leaderboard.providerBests.map(\.provider), [.claude, .codex, .gemini])
    }

    func testLoadDashboardUsageChartsBuildsHourlyAndDailyRollups() {
        let store = TelemetryStore(baseDirectoryURL: temporaryDirectoryURL, maxStoredActivities: 10)
        let calendar = Calendar(identifier: .gregorian)
        let baseDate = Date(timeIntervalSince1970: 1_780_110_000)
        let now = calendar.startOfDay(for: baseDate).addingTimeInterval(23 * 60 * 60)
        let startOfDay = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfDay)!

        store.recordUsage(snapshot: SnapshotFixtures.snapshot(
            usage: [
                SnapshotFixtures.usage(provider: .claude, todayTokens: 180_000, fiveHourTokens: 80_000, weekTokens: 500_000),
                SnapshotFixtures.usage(provider: .codex, todayTokens: 70_000, fiveHourTokens: 35_000, weekTokens: 290_000)
            ],
            lastUpdatedAt: yesterday.addingTimeInterval(18 * 60 * 60),
            mode: .live
        ))

        store.recordUsage(snapshot: SnapshotFixtures.snapshot(
            usage: [
                SnapshotFixtures.usage(provider: .claude, todayTokens: 210_000, fiveHourTokens: 90_000, weekTokens: 540_000),
                SnapshotFixtures.usage(provider: .codex, todayTokens: 90_000, fiveHourTokens: 42_000, weekTokens: 310_000)
            ],
            lastUpdatedAt: startOfDay.addingTimeInterval(9 * 60 * 60),
            mode: .live
        ))

        store.recordUsage(snapshot: SnapshotFixtures.snapshot(
            usage: [
                SnapshotFixtures.usage(provider: .claude, todayTokens: 420_000, fiveHourTokens: 160_000, weekTokens: 760_000),
                SnapshotFixtures.usage(provider: .codex, todayTokens: 140_000, fiveHourTokens: 58_000, weekTokens: 430_000)
            ],
            lastUpdatedAt: startOfDay.addingTimeInterval(14 * 60 * 60),
            mode: .live
        ))

        let charts = store.loadDashboardUsageCharts(now: now)

        XCTAssertEqual(charts.hourly.count, 24)
        XCTAssertEqual(charts.hourly.first?.timestamp, startOfDay)
        XCTAssertEqual(charts.hourly[9].totalTokens, 300_000)
        XCTAssertEqual(charts.hourly[14].totalTokens, 560_000)
        XCTAssertEqual(charts.daily.count, 7)
        XCTAssertEqual(charts.daily.last?.totalTokens, 560_000)
        XCTAssertEqual(charts.daily.dropLast().last?.totalTokens, 250_000)
    }
}
