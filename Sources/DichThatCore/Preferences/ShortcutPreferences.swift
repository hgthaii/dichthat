import Foundation

public protocol ShortcutPersisting: AnyObject {
    func loadShortcut() -> KeyboardShortcut
    func saveShortcut(_ shortcut: KeyboardShortcut) throws
}

public enum ShortcutPreferencesError: Error, Equatable, Sendable {
    case invalidShortcut(KeyboardShortcut.ValidationError)
    case encodingFailed
}

public final class ShortcutPreferences: ShortcutPersisting {
    public static let storageKey = CoreConfiguration.PreferenceKeys.globalKeyboardShortcut

    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = ShortcutPreferences.storageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public func loadShortcut() -> KeyboardShortcut {
        guard
            let data = defaults.data(forKey: storageKey),
            let shortcut = try? decoder.decode(KeyboardShortcut.self, from: data),
            (try? shortcut.validate()) != nil
        else {
            return .defaultShortcut
        }
        return shortcut
    }

    public func saveShortcut(_ shortcut: KeyboardShortcut) throws {
        do {
            try shortcut.validate()
        } catch let error {
            throw ShortcutPreferencesError.invalidShortcut(error)
        }

        guard let data = try? encoder.encode(shortcut) else {
            throw ShortcutPreferencesError.encodingFailed
        }
        defaults.set(data, forKey: storageKey)
    }
}
