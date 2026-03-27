import Foundation

final class AppConfigurationStore {
    private enum Keys {
        static let providerMode = "providerMode"
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var providerMode: ProviderMode {
        get {
            guard
                let rawValue = userDefaults.string(forKey: Keys.providerMode),
                let mode = ProviderMode(rawValue: rawValue)
            else {
                return .mock
            }

            return mode
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: Keys.providerMode)
        }
    }

    var refreshIntervalMinutes: Int {
        get {
            let storedValue = userDefaults.integer(forKey: Keys.refreshIntervalMinutes)
            return storedValue == 0 ? 5 : storedValue
        }
        set {
            userDefaults.set(newValue, forKey: Keys.refreshIntervalMinutes)
        }
    }
}
