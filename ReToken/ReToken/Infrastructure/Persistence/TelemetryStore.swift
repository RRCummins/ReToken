import Foundation
import GRDB

struct TelemetryStore {
    private let fileManager: FileManager
    private let baseDirectoryURL: URL?
    private let maxStoredActivities: Int
    private let databaseQueue: DatabaseQueue?

    init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil,
        maxStoredActivities: Int = 250
    ) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
        self.maxStoredActivities = maxStoredActivities
        self.databaseQueue = Self.makeDatabaseQueue(
            fileManager: fileManager,
            baseDirectoryURL: baseDirectoryURL
        )
    }

    func loadRecentActivity(limit: Int = 50) -> [RecentActivityItem] {
        guard let databaseQueue else {
            return []
        }

        do {
            return try databaseQueue.read { db in
                let rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT id, provider, title, detail, occurred_at, source_description
                    FROM recent_activity
                    ORDER BY occurred_at DESC, id ASC
                    LIMIT ?
                    """,
                    arguments: [limit]
                )

                return rows.compactMap(Self.makeActivity(from:))
            }
        } catch {
            assertionFailure("Failed to load telemetry activity: \(error)")
            return []
        }
    }

    func mergePersistingActivity(
        _ incomingItems: [RecentActivityItem],
        visibleLimit: Int = 50
    ) -> [RecentActivityItem] {
        guard let databaseQueue else {
            return Self.mergedActivity(existingItems: [], incomingItems: incomingItems, limit: visibleLimit)
        }

        do {
            try databaseQueue.write { db in
                let seenAt = Date()

                for item in incomingItems {
                    try Self.upsertActivity(item, seenAt: seenAt, db: db)
                }

                try db.execute(
                    sql: """
                    DELETE FROM recent_activity
                    WHERE id NOT IN (
                        SELECT id
                        FROM recent_activity
                        ORDER BY occurred_at DESC, id ASC
                        LIMIT ?
                    )
                    """,
                    arguments: [maxStoredActivities]
                )
            }

            return loadRecentActivity(limit: visibleLimit)
        } catch {
            assertionFailure("Failed to merge telemetry activity: \(error)")
            return Self.mergedActivity(existingItems: [], incomingItems: incomingItems, limit: visibleLimit)
        }
    }

    func recordUsage(snapshot: AppSnapshot) {
        guard let databaseQueue else {
            return
        }

        let accountsByProvider = Dictionary(uniqueKeysWithValues: snapshot.accounts.map { ($0.provider, $0) })

        do {
            try databaseQueue.write { db in
                for usageSnapshot in snapshot.usage {
                    let accountSnapshot = accountsByProvider[usageSnapshot.provider]

                    try db.execute(
                        sql: """
                        INSERT INTO usage_samples (
                            provider,
                            mode,
                            freshness,
                            recorded_at,
                            today_tokens,
                            window_description,
                            burn_description,
                            account_status,
                            account_label,
                            plan_label,
                            billing_status,
                            data_source_label
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [
                            usageSnapshot.provider.rawValue,
                            snapshot.mode.rawValue,
                            snapshot.freshness.rawValue,
                            snapshot.lastUpdatedAt,
                            usageSnapshot.todayTokens,
                            usageSnapshot.windowDescription,
                            usageSnapshot.burnDescription,
                            usageSnapshot.accountStatus,
                            accountSnapshot?.accountLabel,
                            accountSnapshot?.planLabel,
                            accountSnapshot?.billingStatus,
                            snapshot.dataSourceLabel
                        ]
                    )
                }
            }
        } catch {
            assertionFailure("Failed to record usage telemetry: \(error)")
        }
    }

    func loadUsageTrackingSummary() -> UsageTrackingSummary {
        guard let databaseQueue else {
            return .empty
        }

        do {
            return try databaseQueue.read { db in
                let sampleCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM usage_samples") ?? 0
                guard sampleCount > 0 else {
                    return .empty
                }

                let trackedProviderCount = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(DISTINCT provider) FROM usage_samples"
                ) ?? 0

                let lastRecordedRow = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT recorded_at
                    FROM usage_samples
                    ORDER BY recorded_at DESC
                    LIMIT 1
                    """
                )

                let peakRow = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT provider, today_tokens
                    FROM usage_samples
                    ORDER BY today_tokens DESC, recorded_at DESC
                    LIMIT 1
                    """
                )

                let lastRecordedAt: Date? = lastRecordedRow?["recorded_at"]
                let peakProvider = peakRow.flatMap { row in
                    let providerRawValue: String? = row["provider"]
                    return providerRawValue.flatMap(ProviderKind.init(rawValue:))
                }
                let peakTokens: Int = peakRow?["today_tokens"] ?? 0

                return UsageTrackingSummary(
                    sampleCount: sampleCount,
                    trackedProviderCount: trackedProviderCount,
                    lastRecordedAt: lastRecordedAt,
                    peakProvider: peakProvider,
                    peakTokens: peakTokens
                )
            }
        } catch {
            assertionFailure("Failed to load usage tracking summary: \(error)")
            return .empty
        }
    }

    func loadUsageLeaderboardSummary() -> UsageLeaderboardSummary {
        guard let databaseQueue else {
            return .empty
        }

        do {
            return try databaseQueue.read { db in
                let totalRows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT recorded_at, SUM(today_tokens) AS total_tokens
                    FROM usage_samples
                    GROUP BY recorded_at
                    ORDER BY total_tokens DESC, recorded_at ASC
                    """
                )

                guard totalRows.isEmpty == false else {
                    return .empty
                }

                let latestTotalRow = try Row.fetchOne(
                    db,
                    sql: """
                    SELECT recorded_at, SUM(today_tokens) AS total_tokens
                    FROM usage_samples
                    GROUP BY recorded_at
                    ORDER BY recorded_at DESC
                    LIMIT 1
                    """
                )

                let providerRows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT provider, MAX(today_tokens) AS best_tokens, COUNT(*) AS sample_count
                    FROM usage_samples
                    GROUP BY provider
                    ORDER BY best_tokens DESC, sample_count DESC, provider ASC
                    """
                )

                let providerBests = providerRows.compactMap(Self.makeLeaderboardEntry(from:))
                let mostTrackedEntry = providerBests.max {
                    if $0.sampleCount == $1.sampleCount {
                        return $0.bestTokens < $1.bestTokens
                    }

                    return $0.sampleCount < $1.sampleCount
                }

                let bestRecordedAt: Date? = totalRows.first?["recorded_at"]
                let bestRecordedTotal: Int = totalRows.first?["total_tokens"] ?? 0
                let latestTotal: Int = latestTotalRow?["total_tokens"] ?? 0
                let currentRunRank = totalRows.firstIndex { row in
                    let rowTotal: Int = row["total_tokens"] ?? 0
                    return rowTotal == latestTotal
                }.map { $0 + 1 }

                return UsageLeaderboardSummary(
                    currentRunRank: currentRunRank,
                    bestRecordedTotal: bestRecordedTotal,
                    bestRecordedAt: bestRecordedAt,
                    mostTrackedProvider: mostTrackedEntry?.provider,
                    mostTrackedSampleCount: mostTrackedEntry?.sampleCount ?? 0,
                    providerBests: providerBests
                )
            }
        } catch {
            assertionFailure("Failed to load usage leaderboard summary: \(error)")
            return .empty
        }
    }

    private static func upsertActivity(_ item: RecentActivityItem, seenAt: Date, db: Database) throws {
        let existingRow = try Row.fetchOne(
            db,
            sql: """
            SELECT occurred_at
            FROM recent_activity
            WHERE id = ?
            """,
            arguments: [item.id]
        )

        let existingOccurredAt: Date? = existingRow?["occurred_at"]
        let shouldReplace = existingOccurredAt.map { item.occurredAt >= $0 } ?? true

        if shouldReplace {
            try db.execute(
                sql: """
                INSERT INTO recent_activity (
                    id,
                    provider,
                    title,
                    detail,
                    occurred_at,
                    source_description,
                    last_seen_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    provider = excluded.provider,
                    title = excluded.title,
                    detail = excluded.detail,
                    occurred_at = excluded.occurred_at,
                    source_description = excluded.source_description,
                    last_seen_at = excluded.last_seen_at
                """,
                arguments: [
                    item.id,
                    item.provider.rawValue,
                    item.title,
                    item.detail,
                    item.occurredAt,
                    item.sourceDescription,
                    seenAt
                ]
            )
        } else {
            try db.execute(
                sql: """
                UPDATE recent_activity
                SET last_seen_at = ?
                WHERE id = ?
                """,
                arguments: [seenAt, item.id]
            )
        }
    }

    private static func makeActivity(from row: Row) -> RecentActivityItem? {
        guard let providerRawValue: String = row["provider"],
              let provider = ProviderKind(rawValue: providerRawValue),
              let id: String = row["id"],
              let title: String = row["title"],
              let detail: String = row["detail"],
              let occurredAt: Date = row["occurred_at"],
              let sourceDescription: String = row["source_description"] else {
            return nil
        }

        return RecentActivityItem(
            id: id,
            provider: provider,
            title: title,
            detail: detail,
            occurredAt: occurredAt,
            sourceDescription: sourceDescription
        )
    }

    private static func makeLeaderboardEntry(from row: Row) -> UsageLeaderboardEntry? {
        guard let providerRawValue: String = row["provider"],
              let provider = ProviderKind(rawValue: providerRawValue) else {
            return nil
        }

        let bestTokens: Int = row["best_tokens"] ?? 0
        let sampleCount: Int = row["sample_count"] ?? 0
        return UsageLeaderboardEntry(provider: provider, bestTokens: bestTokens, sampleCount: sampleCount)
    }

    private static func mergedActivity(
        existingItems: [RecentActivityItem],
        incomingItems: [RecentActivityItem],
        limit: Int
    ) -> [RecentActivityItem] {
        var itemsByID: [String: RecentActivityItem] = [:]

        existingItems.forEach { itemsByID[$0.id] = $0 }

        incomingItems.forEach { item in
            guard let existingItem = itemsByID[item.id] else {
                itemsByID[item.id] = item
                return
            }

            if item.occurredAt >= existingItem.occurredAt {
                itemsByID[item.id] = item
            }
        }

        return itemsByID.values
            .sorted {
                if $0.occurredAt == $1.occurredAt {
                    return $0.id < $1.id
                }

                return $0.occurredAt > $1.occurredAt
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func makeDatabaseQueue(
        fileManager: FileManager,
        baseDirectoryURL: URL?
    ) -> DatabaseQueue? {
        let databaseURL = makeDatabaseURL(fileManager: fileManager, baseDirectoryURL: baseDirectoryURL)

        do {
            try fileManager.createDirectory(
                at: databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let databaseQueue = try DatabaseQueue(path: databaseURL.path)
            var migrator = DatabaseMigrator()

            migrator.registerMigration("createTelemetry") { db in
                try db.create(table: "usage_samples") { table in
                    table.autoIncrementedPrimaryKey("id")
                    table.column("provider", .text).notNull()
                    table.column("mode", .text).notNull()
                    table.column("freshness", .text).notNull()
                    table.column("recorded_at", .datetime).notNull().indexed()
                    table.column("today_tokens", .integer).notNull()
                    table.column("window_description", .text).notNull()
                    table.column("burn_description", .text).notNull()
                    table.column("account_status", .text).notNull()
                    table.column("account_label", .text)
                    table.column("plan_label", .text)
                    table.column("billing_status", .text)
                    table.column("data_source_label", .text).notNull()
                }

                try db.create(table: "recent_activity") { table in
                    table.column("id", .text).primaryKey()
                    table.column("provider", .text).notNull()
                    table.column("title", .text).notNull()
                    table.column("detail", .text).notNull()
                    table.column("occurred_at", .datetime).notNull().indexed()
                    table.column("source_description", .text).notNull()
                    table.column("last_seen_at", .datetime).notNull()
                }
            }

            try migrator.migrate(databaseQueue)
            return databaseQueue
        } catch {
            assertionFailure("Failed to initialize telemetry database: \(error)")
            return nil
        }
    }

    private static func makeDatabaseURL(
        fileManager: FileManager,
        baseDirectoryURL: URL?
    ) -> URL {
        let directoryURL = baseDirectoryURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

        return directoryURL
            .appendingPathComponent("ReToken", isDirectory: true)
            .appendingPathComponent("telemetry.sqlite", isDirectory: false)
    }
}
