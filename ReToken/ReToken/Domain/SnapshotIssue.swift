import Foundation

struct SnapshotIssue: Codable, Identifiable {
    let id: UUID
    let provider: ProviderKind?
    let message: String

    init(id: UUID = UUID(), provider: ProviderKind? = nil, message: String) {
        self.id = id
        self.provider = provider
        self.message = message
    }
}
