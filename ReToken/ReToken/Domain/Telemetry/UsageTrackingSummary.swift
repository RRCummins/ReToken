import Foundation

struct UsageTrackingSummary: Codable {
    let sampleCount: Int
    let trackedProviderCount: Int
    let lastRecordedAt: Date?
    let peakProvider: ProviderKind?
    let peakTokens: Int

    var isEmpty: Bool {
        sampleCount == 0
    }

    static let empty = UsageTrackingSummary(
        sampleCount: 0,
        trackedProviderCount: 0,
        lastRecordedAt: nil,
        peakProvider: nil,
        peakTokens: 0
    )
}
