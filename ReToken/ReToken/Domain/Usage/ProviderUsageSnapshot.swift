import Foundation

struct ProviderUsageSnapshot: Codable, Identifiable {
    let provider: ProviderKind
    let todayTokens: Int
    let windowDescription: String
    let burnDescription: String
    let accountStatus: String

    var id: ProviderKind { provider }
}
