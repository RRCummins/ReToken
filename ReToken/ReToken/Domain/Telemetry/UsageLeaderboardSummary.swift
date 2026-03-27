import Foundation

struct UsageLeaderboardSummary: Codable, Equatable {
    let currentRunRank: Int?
    let bestRecordedTotal: Int
    let bestRecordedAt: Date?
    let mostTrackedProvider: ProviderKind?
    let mostTrackedSampleCount: Int
    let providerBests: [UsageLeaderboardEntry]

    var championEntry: UsageLeaderboardEntry? {
        providerBests.first
    }

    var isEmpty: Bool {
        bestRecordedTotal == 0 && providerBests.isEmpty
    }

    static let empty = UsageLeaderboardSummary(
        currentRunRank: nil,
        bestRecordedTotal: 0,
        bestRecordedAt: nil,
        mostTrackedProvider: nil,
        mostTrackedSampleCount: 0,
        providerBests: []
    )
}
