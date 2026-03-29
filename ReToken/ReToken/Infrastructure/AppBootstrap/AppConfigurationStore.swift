import Foundation

final class AppConfigurationStore {
    private enum Keys {
        static let providerMode = "providerMode"
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let menuBarShowsLifetime = "menuBarShowsLifetime"
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
                return .live   // always default to live — mock is dev-only
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

    /// When true the menu-bar status item shows the all-time lifetime token total;
    /// when false it shows today's total.
    var menuBarShowsLifetime: Bool {
        get { userDefaults.bool(forKey: Keys.menuBarShowsLifetime) }
        set { userDefaults.set(newValue, forKey: Keys.menuBarShowsLifetime) }
    }
}
