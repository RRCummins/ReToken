import XCTest
@testable import ReToken

final class ProviderSnapshotComposerTests: XCTestCase {
    func testMakeSnapshotSortsProvidersAndActivityChronologically() async {
        let now = Date(timeIntervalSince1970: 1_700_200_000)

        let adapters: [any ProviderAdapter] = [
            StaticProviderAdapter(
                provider: .gemini,
                bundle: ProviderSnapshotBundle(
                    usage: SnapshotFixtures.usage(provider: .gemini, todayTokens: 300),
                    account: SnapshotFixtures.account(provider: .gemini),
                    recentActivity: [
                        SnapshotFixtures.activity(
                            provider: .gemini,
                            title: "Gemini latest",
                            occurredAt: now.addingTimeInterval(-60)
                        )
                    ],
                    issues: [SnapshotIssue(provider: .gemini, message: "Gemini issue")]
                )
            ),
            StaticProviderAdapter(
                provider: .claude,
                bundle: ProviderSnapshotBundle(
                    usage: SnapshotFixtures.usage(provider: .claude, todayTokens: 100),
                    account: SnapshotFixtures.account(provider: .claude),
                    recentActivity: [
                        SnapshotFixtures.activity(
                            provider: .claude,
                            title: "Claude oldest",
                            occurredAt: now.addingTimeInterval(-180)
                        )
                    ],
                    issues: []
                )
            ),
            StaticProviderAdapter(
                provider: .codex,
                bundle: ProviderSnapshotBundle(
                    usage: SnapshotFixtures.usage(provider: .codex, todayTokens: 200),
                    account: SnapshotFixtures.account(provider: .codex),
                    recentActivity: [
                        SnapshotFixtures.activity(
                            provider: .codex,
                            title: "Codex newest",
                            occurredAt: now.addingTimeInterval(-30)
                        )
                    ],
                    issues: [SnapshotIssue(provider: .codex, message: "Codex issue")]
                )
            )
        ]

        let snapshot = await ProviderSnapshotComposer.makeSnapshot(
            from: adapters,
            mode: .live,
            refreshCount: 4,
            now: now,
            freshness: .fresh,
            dataSourceLabel: "Live Providers"
        )

        XCTAssertEqual(snapshot.usage.map(\.provider), [.claude, .codex, .gemini])
        XCTAssertEqual(snapshot.accounts.map(\.provider), [.claude, .codex, .gemini])
        XCTAssertEqual(snapshot.recentActivity.map(\.title), ["Codex newest", "Gemini latest", "Claude oldest"])
        XCTAssertEqual(snapshot.issues.map(\.message), ["Gemini issue", "Codex issue"])
        XCTAssertEqual(snapshot.lastUpdatedAt, now)
        XCTAssertEqual(snapshot.mode, .live)
        XCTAssertEqual(snapshot.freshness, .fresh)
        XCTAssertEqual(snapshot.dataSourceLabel, "Live Providers")
    }
}

private struct StaticProviderAdapter: ProviderAdapter {
    let provider: ProviderKind
    let bundle: ProviderSnapshotBundle

    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle {
        bundle
    }
}
