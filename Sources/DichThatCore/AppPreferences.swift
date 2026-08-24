import Foundation

public protocol AppPreferencePersisting: AnyObject {
    func loadShowSelectionIcon() -> Bool
    func saveShowSelectionIcon(_ isEnabled: Bool)
}

public final class AppPreferences: AppPreferencePersisting {
    public enum Keys {
        public static let showSelectionIcon = "showSelectionIconWhenTextIsSelected"
    }

    public static let defaultShowSelectionIcon = true

    private let defaults: UserDefaults
    private let showSelectionIconKey: String

    public init(
        defaults: UserDefaults = .standard,
        showSelectionIconKey: String = AppPreferences.Keys.showSelectionIcon
    ) {
        self.defaults = defaults
        self.showSelectionIconKey = showSelectionIconKey
    }

    public func loadShowSelectionIcon() -> Bool {
        guard let value = defaults.object(forKey: showSelectionIconKey) as? Bool else {
            return Self.defaultShowSelectionIcon
        }
        return value
    }

    public func saveShowSelectionIcon(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: showSelectionIconKey)
    }
}
