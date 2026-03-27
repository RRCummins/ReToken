import XCTest
@testable import ReToken

final class AppSnapshotFormatterTests: XCTestCase {
    func testStatusTitleUsesCompactMillionsAndWarningMarker() {
        let snapshot = SnapshotFixtures.snapshot(
            usage: [
                SnapshotFixtures.usage(provider: .codex, todayTokens: 1_200_000),
                SnapshotFixtures.usage(provider: .claude, todayTokens: 34_500)
            ],
            issues: [SnapshotIssue(provider: .codex, message: "Rate limit warning")]
        )

        XCTAssertEqual(AppSnapshotFormatter.statusTitle(for: snapshot), "RT 1.2M !")
    }

    func testTooltipIncludesModeFreshnessAndTokenTotal() {
        let snapshot = SnapshotFixtures.snapshot(
            usage: [
                SnapshotFixtures.usage(provider: .claude, todayTokens: 1_250),
                SnapshotFixtures.usage(provider: .gemini, todayTokens: 750)
            ],
            mode: .live,
            freshness: .cached
        )

        XCTAssertEqual(
            AppSnapshotFormatter.tooltip(for: snapshot),
            "ReToken • 2.0K tokens today • Live • cached"
        )
    }

    func testIssuesDashboardTextFallsBackWhenNoIssuesExist() {
        let snapshot = SnapshotFixtures.snapshot(
            usage: [SnapshotFixtures.usage(provider: .claude, todayTokens: 90)]
        )

        XCTAssertEqual(AppSnapshotFormatter.issuesDashboardText(for: snapshot), "No active issues")
    }

    func testIssuesDashboardTextPrefixesProviderNames() {
        let snapshot = SnapshotFixtures.snapshot(
            usage: [SnapshotFixtures.usage(provider: .claude, todayTokens: 90)],
            issues: [
                SnapshotIssue(provider: .claude, message: "Admin key missing"),
                SnapshotIssue(message: "Cache is stale")
            ]
        )

        XCTAssertEqual(
            AppSnapshotFormatter.issuesDashboardText(for: snapshot),
            """
            Claude: Admin key missing
            Cache is stale
            """
        )
    }

    func testTrackingDashboardTextDescribesRecordedSamples() {
        let snapshot = SnapshotFixtures.snapshot(
            usage: [SnapshotFixtures.usage(provider: .codex, todayTokens: 90)],
            usageTrackingSummary: UsageTrackingSummary(
                sampleCount: 12,
                trackedProviderCount: 3,
                lastRecordedAt: Date(),
                peakProvider: .claude,
                peakTokens: 1_240_000
            )
        )

        let text = AppSnapshotFormatter.trackingDashboardText(for: snapshot)

        XCTAssertTrue(text.contains("12 samples across 3 agents"))
        XCTAssertTrue(text.contains("peak Claude 1.2M"))
    }

    func testLeaderboardDashboardTextHighlightsCurrentRankAndChamp() {
        let snapshot = SnapshotFixtures.snapshot(
            usage: [SnapshotFixtures.usage(provider: .codex, todayTokens: 1_800_000)],
            leaderboardSummary: UsageLeaderboardSummary(
                currentRunRank: 1,
                bestRecordedTotal: 1_800_000,
                bestRecordedAt: Date(),
                mostTrackedProvider: .claude,
                mostTrackedSampleCount: 14,
                providerBests: [
                    UsageLeaderboardEntry(provider: .codex, bestTokens: 1_240_000, sampleCount: 10),
                    UsageLeaderboardEntry(provider: .claude, bestTokens: 980_000, sampleCount: 14)
                ]
            )
        )

        let text = AppSnapshotFormatter.leaderboardDashboardText(for: snapshot)

        XCTAssertTrue(text.contains("Current run rank: #1"))
        XCTAssertTrue(text.contains("All-time champ: Codex"))
        XCTAssertTrue(text.contains("Most tracked: Claude"))
    }
}
