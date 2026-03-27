import Foundation

protocol LocalProviderSnapshotReader {
    var provider: ProviderKind { get }
    func readSnapshot(now: Date) throws -> ProviderSnapshotBundle
}

enum LocalProviderSnapshotError: LocalizedError {
    case missingSource(String)
    case invalidSource(String)
    case unreadableSource(String)

    var errorDescription: String? {
        switch self {
        case let .missingSource(message):
            return message
        case let .invalidSource(message):
            return message
        case let .unreadableSource(message):
            return message
        }
    }
}
