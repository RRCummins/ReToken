import Foundation

struct ProviderUsageSnapshot: Codable, Identifiable {
    let provider: ProviderKind
    let todayTokens: Int
    let todayInputTokens: Int?
    let todayOutputTokens: Int?
    let fiveHourTokens: Int
    let weekTokens: Int
    let fiveHourUsedPercent: Double?
    let fiveHourResetAt: Date?
    let weekUsedPercent: Double?
    let weekResetAt: Date?
    let lifetimeTokens: Int
    let windowDescription: String
    let burnDescription: String
    let accountStatus: String
    let isVisible: Bool

    var id: ProviderKind { provider }

    init(
        provider: ProviderKind,
        todayTokens: Int,
        todayInputTokens: Int? = nil,
        todayOutputTokens: Int? = nil,
        fiveHourTokens: Int = 0,
        weekTokens: Int = 0,
        fiveHourUsedPercent: Double? = nil,
        fiveHourResetAt: Date? = nil,
        weekUsedPercent: Double? = nil,
        weekResetAt: Date? = nil,
        lifetimeTokens: Int = 0,
        windowDescription: String,
        burnDescription: String,
        accountStatus: String,
        isVisible: Bool = true
    ) {
        self.provider = provider
        self.todayTokens = todayTokens
        self.todayInputTokens = todayInputTokens
        self.todayOutputTokens = todayOutputTokens
        self.fiveHourTokens = fiveHourTokens
        self.weekTokens = weekTokens
        self.fiveHourUsedPercent = fiveHourUsedPercent
        self.fiveHourResetAt = fiveHourResetAt
        self.weekUsedPercent = weekUsedPercent
        self.weekResetAt = weekResetAt
        self.lifetimeTokens = lifetimeTokens
        self.windowDescription = windowDescription
        self.burnDescription = burnDescription
        self.accountStatus = accountStatus
        self.isVisible = isVisible
    }

    // Backward-compatible decoder for older stored snapshots.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = try c.decode(ProviderKind.self, forKey: .provider)
        todayTokens = try c.decode(Int.self, forKey: .todayTokens)
        todayInputTokens = try? c.decodeIfPresent(Int.self, forKey: .todayInputTokens)
        todayOutputTokens = try? c.decodeIfPresent(Int.self, forKey: .todayOutputTokens)
        fiveHourTokens = (try? c.decodeIfPresent(Int.self, forKey: .fiveHourTokens)) ?? 0
        weekTokens = (try? c.decodeIfPresent(Int.self, forKey: .weekTokens)) ?? 0
        fiveHourUsedPercent = try? c.decodeIfPresent(Double.self, forKey: .fiveHourUsedPercent)
        fiveHourResetAt = try? c.decodeIfPresent(Date.self, forKey: .fiveHourResetAt)
        weekUsedPercent = try? c.decodeIfPresent(Double.self, forKey: .weekUsedPercent)
        weekResetAt = try? c.decodeIfPresent(Date.self, forKey: .weekResetAt)
        lifetimeTokens = (try? c.decodeIfPresent(Int.self, forKey: .lifetimeTokens)) ?? 0
        windowDescription = try c.decode(String.self, forKey: .windowDescription)
        burnDescription = try c.decode(String.self, forKey: .burnDescription)
        accountStatus = try c.decode(String.self, forKey: .accountStatus)
        isVisible = (try? c.decodeIfPresent(Bool.self, forKey: .isVisible)) ?? true
    }
}
