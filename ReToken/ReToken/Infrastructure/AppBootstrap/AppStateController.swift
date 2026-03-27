import Foundation

extension Notification.Name {
    static let appStateControllerDidChange = Notification.Name("AppStateController.didChange")
}

final class AppStateController {
    private static let staleThreshold: TimeInterval = 15 * 60

    private let notificationCenter: NotificationCenter
    private let snapshotStore: AppSnapshotStore
    private let telemetryStore: TelemetryStore
    private let configurationStore: AppConfigurationStore
    private let mockProviderAdapters: [any ProviderAdapter]
    private let liveProviderAdapters: [any ProviderAdapter]
    private var refreshTask: Task<Void, Never>?
    private var automaticRefreshTimer: Timer?
    private var refreshCount = 0

    private(set) var snapshot: AppSnapshot {
        didSet {
            notificationCenter.post(name: .appStateControllerDidChange, object: self)
        }
    }

    init(
        notificationCenter: NotificationCenter = .default,
        snapshotStore: AppSnapshotStore = AppSnapshotStore(),
        telemetryStore: TelemetryStore = TelemetryStore(),
        configurationStore: AppConfigurationStore = AppConfigurationStore(),
        mockProviderAdapters: [any ProviderAdapter] = [
            MockClaudeProviderAdapter(),
            MockCodexProviderAdapter(),
            MockGeminiProviderAdapter()
        ],
        liveProviderAdapters: [any ProviderAdapter] = [
            LiveClaudeProviderAdapter(),
            LiveCodexProviderAdapter(),
            LiveGeminiProviderAdapter()
        ]
    ) {
        self.notificationCenter = notificationCenter
        self.snapshotStore = snapshotStore
        self.telemetryStore = telemetryStore
        self.configurationStore = configurationStore
        self.mockProviderAdapters = mockProviderAdapters
        self.liveProviderAdapters = liveProviderAdapters

        let selectedMode = configurationStore.providerMode
        let persistedActivity = telemetryStore.loadRecentActivity()
        let trackingSummary = telemetryStore.loadUsageTrackingSummary()
        let leaderboardSummary = telemetryStore.loadUsageLeaderboardSummary()
        if let storedSnapshot = snapshotStore.load(), storedSnapshot.mode == selectedMode {
            self.snapshot = Self.classifyStoredSnapshot(
                storedSnapshot.replacing(
                    freshness: storedSnapshot.freshness,
                    recentActivity: persistedActivity.isEmpty ? storedSnapshot.recentActivity : persistedActivity,
                    usageTrackingSummary: trackingSummary,
                    leaderboardSummary: leaderboardSummary
                )
            )
        } else {
            self.snapshot = AppSnapshot(
                usage: [],
                accounts: [],
                recentActivity: persistedActivity,
                usageTrackingSummary: trackingSummary,
                leaderboardSummary: leaderboardSummary,
                lastUpdatedAt: .now,
                mode: selectedMode,
                freshness: .fresh,
                dataSourceLabel: "initializing \(selectedMode.displayName.lowercased()) adapters",
                issues: []
            )
        }
    }

    func refreshData() {
        refreshCount += 1
        let nextRefreshCount = refreshCount
        let mode = providerMode
        let adapters = activeAdapters

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            let nextSnapshot = await ProviderSnapshotComposer.makeSnapshot(
                from: adapters,
                mode: mode,
                refreshCount: nextRefreshCount,
                freshness: .fresh,
                dataSourceLabel: "\(mode.displayName.lowercased()) adapters"
            )

            guard Task.isCancelled == false else {
                return
            }

            let mergedActivity = self.telemetryStore.mergePersistingActivity(nextSnapshot.recentActivity)
            var persistedSnapshot = nextSnapshot.replacing(
                freshness: nextSnapshot.freshness,
                recentActivity: mergedActivity
            )

            self.telemetryStore.recordUsage(snapshot: persistedSnapshot)
            persistedSnapshot = persistedSnapshot.replacing(
                freshness: persistedSnapshot.freshness,
                usageTrackingSummary: self.telemetryStore.loadUsageTrackingSummary(),
                leaderboardSummary: self.telemetryStore.loadUsageLeaderboardSummary()
            )

            self.snapshot = persistedSnapshot
            self.snapshotStore.save(persistedSnapshot)
        }
    }

    var providerMode: ProviderMode {
        configurationStore.providerMode
    }

    func setProviderMode(_ mode: ProviderMode) {
        guard configurationStore.providerMode != mode else {
            return
        }

        configurationStore.providerMode = mode
        refreshData()
    }

    var refreshIntervalMinutes: Int {
        configurationStore.refreshIntervalMinutes
    }

    func setRefreshIntervalMinutes(_ minutes: Int) {
        guard configurationStore.refreshIntervalMinutes != minutes else {
            return
        }

        configurationStore.refreshIntervalMinutes = minutes
        scheduleAutomaticRefresh()
        notificationCenter.post(name: .appStateControllerDidChange, object: self)
    }

    func startAutomaticRefresh() {
        scheduleAutomaticRefresh()
    }

    deinit {
        automaticRefreshTimer?.invalidate()
        refreshTask?.cancel()
    }

    private var activeAdapters: [any ProviderAdapter] {
        Self.adapters(
            for: providerMode,
            mockProviderAdapters: mockProviderAdapters,
            liveProviderAdapters: liveProviderAdapters
        )
    }

    private static func adapters(
        for mode: ProviderMode,
        mockProviderAdapters: [any ProviderAdapter],
        liveProviderAdapters: [any ProviderAdapter]
    ) -> [any ProviderAdapter] {
        switch mode {
        case .mock:
            return mockProviderAdapters
        case .live:
            return liveProviderAdapters
        }
    }

    private static func classifyStoredSnapshot(_ snapshot: AppSnapshot, now: Date = .now) -> AppSnapshot {
        let age = now.timeIntervalSince(snapshot.lastUpdatedAt)
        let freshness: SnapshotFreshness = age > staleThreshold ? .stale : .cached
        let label = freshness == .stale ? "\(snapshot.dataSourceLabel) • restored stale cache" : "\(snapshot.dataSourceLabel) • restored cache"
        return snapshot.replacing(freshness: freshness, dataSourceLabel: label)
    }

    private func scheduleAutomaticRefresh() {
        automaticRefreshTimer?.invalidate()

        let interval = TimeInterval(refreshIntervalMinutes * 60)
        automaticRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
    }
}
