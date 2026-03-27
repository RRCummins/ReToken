import Foundation

struct AccountSnapshot: Codable, Identifiable {
    let provider: ProviderKind
    let accountLabel: String
    let planLabel: String
    let billingStatus: String

    var id: ProviderKind { provider }
}
