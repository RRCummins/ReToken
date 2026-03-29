import Foundation

struct LiveGeminiProviderAdapter: ProviderAdapter {
    let provider: ProviderKind = .gemini

    private let chatRootURL: URL
    private let historyRootURL: URL

    init(
        chatRootURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".gemini/tmp"),
        historyRootURL: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".gemini/history")
    ) {
        self.chatRootURL = chatRootURL
        self.historyRootURL = historyRootURL
    }

    func fetchSnapshot(context: ProviderFetchContext) async -> ProviderSnapshotBundle {
        do {
            let summary = try loadLocalSummary(now: context.now)
            guard summary.sessionCount > 0 else {
                return unavailableBundle(detail: "No Gemini local chats found in ~/.gemini/tmp")
            }

            return ProviderSnapshotBundle(
                usage: ProviderUsageSnapshot(
                    provider: provider,
                    todayTokens: summary.todayTokens,
                    todayInputTokens: summary.todayInputTokens,
                    todayOutputTokens: summary.todayOutputTokens,
                    fiveHourTokens: summary.fiveHourTokens,
                    weekTokens: summary.weekTokens,
                    lifetimeTokens: summary.lifetimeTokens,
                    windowDescription: "\(summary.responseCount) responses • \(summary.sessionCount) sessions tracked",
                    burnDescription: Self.burnDescription(for: summary.todayTokens),
                    accountStatus: "Gemini local chat telemetry"
                ),
                account: AccountSnapshot(
                    provider: provider,
                    accountLabel: summary.primaryModel ?? "local workspace activity",
                    planLabel: "Gemini local CLI",
                    billingStatus: "\(summary.responseCount) responses • \(summary.workspaceCount) workspaces"
                ),
                recentActivity: summary.recentActivity,
                issues: []
            )
        } catch {
            return unavailableBundle(detail: error.localizedDescription)
        }
    }

    private func loadLocalSummary(now: Date) throws -> GeminiLocalSummary {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: chatRootURL.path) else {
            throw LocalProviderSnapshotError.missingSource("Gemini local chat root is missing in ~/.gemini/tmp")
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let fiveHourBoundary = now.addingTimeInterval(-(5 * 60 * 60))
        let weekBoundary = now.addingTimeInterval(-(7 * 24 * 60 * 60))
        let workspaceNames = loadWorkspaceNames()

        let workspaceDirectories = try fileManager.contentsOfDirectory(
            at: chatRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }

        var sessionCount = 0
        var responseCount = 0
        var workspaceLabels = Set<String>()
        var todayTokens = 0
        var todayInputTokens = 0
        var todayOutputTokens = 0
        var fiveHourTokens = 0
        var weekTokens = 0
        var lifetimeTokens = 0
        var modelCounts: [String: Int] = [:]
        var activityBySessionID: [String: RecentActivityItem] = [:]

        for workspaceDirectory in workspaceDirectories {
            let chatsDirectory = workspaceDirectory.appending(path: "chats", directoryHint: .isDirectory)
            guard fileManager.fileExists(atPath: chatsDirectory.path) else {
                continue
            }

            let chatFiles = (try? fileManager.contentsOfDirectory(
                at: chatsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension == "json" }) ?? []

            for chatFile in chatFiles {
                if let modificationDate = try? chatFile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modificationDate < weekBoundary {
                    continue
                }

                guard let session = try parseSession(at: chatFile) else {
                    continue
                }

                sessionCount += 1
                let workspaceLabel = workspaceNames[workspaceDirectory.lastPathComponent] ?? workspaceDirectory.lastPathComponent
                workspaceLabels.insert(workspaceLabel)

                var latestGeminiMessage: GeminiLocalMessage?
                var sessionTokenTotal = 0

                for message in session.messages where message.type == "gemini" {
                    responseCount += 1
                    sessionTokenTotal += message.totalTokens
                    lifetimeTokens += message.totalTokens

                    if message.timestamp >= weekBoundary {
                        weekTokens += message.totalTokens
                    }

                    if message.timestamp >= fiveHourBoundary {
                        fiveHourTokens += message.totalTokens
                    }

                    if message.timestamp >= startOfDay {
                        todayTokens += message.totalTokens
                        todayInputTokens += message.inputTokens
                        todayOutputTokens += message.outputTokens
                    }

                    if let model = message.model {
                        modelCounts[model, default: 0] += message.totalTokens
                    }

                    if latestGeminiMessage == nil || message.timestamp > latestGeminiMessage?.timestamp ?? .distantPast {
                        latestGeminiMessage = message
                    }
                }

                if let latestGeminiMessage {
                    activityBySessionID[session.sessionID] = RecentActivityItem(
                        id: "gemini:session:\(session.sessionID)",
                        provider: provider,
                        title: Self.compactTitle(latestGeminiMessage.content),
                        detail: "\(workspaceLabel) • \(AppSnapshotFormatter.compactTokenCount(sessionTokenTotal)) tokens",
                        occurredAt: latestGeminiMessage.timestamp,
                        sourceDescription: "Gemini local chats"
                    )
                }
            }
        }

        let primaryModel = modelCounts.max(by: { $0.value < $1.value }).map { Self.modelDisplayName(for: $0.key) }
        let recentActivity = activityBySessionID.values
            .sorted { $0.occurredAt > $1.occurredAt }
            .prefix(5)
            .map { $0 }

        return GeminiLocalSummary(
            sessionCount: sessionCount,
            responseCount: responseCount,
            workspaceCount: workspaceLabels.count,
            todayTokens: todayTokens,
            todayInputTokens: todayInputTokens,
            todayOutputTokens: todayOutputTokens,
            fiveHourTokens: fiveHourTokens,
            weekTokens: weekTokens,
            lifetimeTokens: lifetimeTokens,
            primaryModel: primaryModel,
            recentActivity: recentActivity
        )
    }

    private func parseSession(at fileURL: URL) throws -> GeminiLocalSession? {
        let data = try Data(contentsOf: fileURL)
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessionID = jsonObject["sessionId"] as? String,
              let rawMessages = jsonObject["messages"] as? [[String: Any]] else {
            return nil
        }

        let messages = rawMessages.compactMap { rawMessage -> GeminiLocalMessage? in
            guard let type = rawMessage["type"] as? String,
                  let timestampString = rawMessage["timestamp"] as? String,
                  let timestamp = Self.parseISO8601(timestampString) else {
                return nil
            }

            let tokens = (rawMessage["tokens"] as? [String: Any]).flatMap { tokenInfo in
                Self.intValue(tokenInfo["total"])
                    ?? [tokenInfo["input"], tokenInfo["output"], tokenInfo["cached"], tokenInfo["thoughts"], tokenInfo["tool"]]
                        .compactMap(Self.intValue)
                        .reduce(0, +)
            } ?? 0
            let tokenInfo = rawMessage["tokens"] as? [String: Any]
            let inputTokens = Self.intValue(tokenInfo?["input"]) ?? 0
            let cachedTokens = Self.intValue(tokenInfo?["cached"]) ?? 0
            let outputTokens = Self.intValue(tokenInfo?["output"]) ?? 0
            let thoughtsTokens = Self.intValue(tokenInfo?["thoughts"]) ?? 0
            let toolTokens = Self.intValue(tokenInfo?["tool"]) ?? 0

            let content = (rawMessage["content"] as? String)
                ?? Self.text(from: rawMessage["content"] as? [[String: Any]])
                ?? type.capitalized

            return GeminiLocalMessage(
                type: type,
                timestamp: timestamp,
                content: content,
                totalTokens: tokens,
                inputTokens: inputTokens + cachedTokens,
                outputTokens: outputTokens + thoughtsTokens + toolTokens,
                model: rawMessage["model"] as? String
            )
        }

        return GeminiLocalSession(sessionID: sessionID, messages: messages)
    }

    private func loadWorkspaceNames() -> [String: String] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: historyRootURL.path) else {
            return [:]
        }

        let historyDirectories = (try? fileManager.contentsOfDirectory(
            at: historyRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }) ?? []

        var names: [String: String] = [:]
        for directory in historyDirectories {
            let rootMarker = directory.appending(path: ".project_root")
            guard let rootPath = try? String(contentsOf: rootMarker, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                  rootPath.isEmpty == false else {
                continue
            }

            names[directory.lastPathComponent] = URL(fileURLWithPath: rootPath).lastPathComponent
        }

        return names
    }

    private func unavailableBundle(detail: String) -> ProviderSnapshotBundle {
        ProviderSnapshotBundle(
            usage: ProviderUsageSnapshot(
                provider: provider,
                todayTokens: 0,
                windowDescription: "Gemini local data unavailable",
                burnDescription: "idle",
                accountStatus: "waiting for Gemini local chat history",
                isVisible: false
            ),
            account: AccountSnapshot(
                provider: provider,
                accountLabel: "not configured",
                planLabel: "Gemini local CLI",
                billingStatus: "unavailable"
            ),
            recentActivity: [],
            issues: [
                SnapshotIssue(provider: provider, message: detail)
            ]
        )
    }

    nonisolated private static func text(from contentItems: [[String: Any]]?) -> String? {
        guard let contentItems else {
            return nil
        }

        let text = contentItems
            .compactMap { $0["text"] as? String }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text.isEmpty ? nil : text
    }

    nonisolated private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }

        if let value = value as? NSNumber {
            return value.intValue
        }

        return nil
    }

    nonisolated private static func compactTitle(_ value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > 88 else {
            return normalized
        }

        let endIndex = normalized.index(normalized.startIndex, offsetBy: 88)
        return String(normalized[..<endIndex]) + "…"
    }

    nonisolated private static func modelDisplayName(for identifier: String) -> String {
        identifier.replacingOccurrences(of: "-", with: " ").capitalized
    }

    nonisolated private static func burnDescription(for tokens: Int) -> String {
        switch tokens {
        case 1_000_000...:
            return "furnace"
        case 150_000...:
            return "hot"
        case 1...:
            return "steady"
        default:
            return "idle"
        }
    }

    nonisolated private static func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private struct GeminiLocalSummary {
    let sessionCount: Int
    let responseCount: Int
    let workspaceCount: Int
    let todayTokens: Int
    let todayInputTokens: Int
    let todayOutputTokens: Int
    let fiveHourTokens: Int
    let weekTokens: Int
    let lifetimeTokens: Int
    let primaryModel: String?
    let recentActivity: [RecentActivityItem]
}

private struct GeminiLocalSession {
    let sessionID: String
    let messages: [GeminiLocalMessage]
}

private struct GeminiLocalMessage {
    let type: String
    let timestamp: Date
    let content: String
    let totalTokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let model: String?
}
