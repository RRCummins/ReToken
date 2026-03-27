import Foundation

struct RecentActivityItem: Codable, Identifiable {
    let id: String
    let provider: ProviderKind
    let title: String
    let detail: String
    let occurredAt: Date
    let sourceDescription: String

    init(
        id: String? = nil,
        provider: ProviderKind,
        title: String,
        detail: String,
        occurredAt: Date,
        sourceDescription: String
    ) {
        self.id = id ?? Self.defaultIdentifier(
            provider: provider,
            title: title,
            detail: detail,
            occurredAt: occurredAt,
            sourceDescription: sourceDescription
        )
        self.provider = provider
        self.title = title
        self.detail = detail
        self.occurredAt = occurredAt
        self.sourceDescription = sourceDescription
    }

    private static func defaultIdentifier(
        provider: ProviderKind,
        title: String,
        detail: String,
        occurredAt: Date,
        sourceDescription: String
    ) -> String {
        let timestamp = Int(occurredAt.timeIntervalSince1970)
        return "\(provider.rawValue)|\(sourceDescription)|\(title)|\(detail)|\(timestamp)"
    }
}
