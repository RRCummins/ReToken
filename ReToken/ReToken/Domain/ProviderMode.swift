import Foundation

enum ProviderMode: String, CaseIterable, Codable {
    case mock
    case live

    var displayName: String {
        switch self {
        case .mock:
            return "Mock"
        case .live:
            return "Live"
        }
    }

    var refreshActionTitle: String {
        switch self {
        case .mock:
            return "Refresh Mock Provider Data"
        case .live:
            return "Refresh Live Provider Data"
        }
    }
}
