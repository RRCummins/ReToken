import Foundation

struct UsageLeaderboardEntry: Codable, Equatable {
    let provider: ProviderKind
    let bestTokens: Int
    let sampleCount: Int
}
