import Foundation

enum SnapshotFreshness: String, Codable {
    case fresh
    case cached
    case stale

    var displayName: String {
        rawValue
    }
}
