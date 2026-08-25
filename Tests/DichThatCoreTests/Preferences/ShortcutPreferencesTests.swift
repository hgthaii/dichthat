import Foundation
import Testing
@testable import DichThatCore

@Test("Saved valid shortcut loads from an isolated defaults suite")
func savedShortcutLoads() throws {
    let suiteName = "DichThatTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = ShortcutPreferences(defaults: defaults)
    let shortcut = KeyboardShortcut(keyCode: 0, modifiers: [.command, .shift])

    try preferences.saveShortcut(shortcut)

    #expect(preferences.loadShortcut() == shortcut)
}

@Test("Missing, corrupt and invalid saved values fall back without overwriting")
func invalidValuesFallBackWithoutOverwrite() throws {
    let suiteName = "DichThatTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = ShortcutPreferences(defaults: defaults)

    #expect(preferences.loadShortcut() == .defaultShortcut)
    #expect(defaults.object(forKey: ShortcutPreferences.storageKey) == nil)

    let corrupt = Data([0xFF, 0x00])
    defaults.set(corrupt, forKey: ShortcutPreferences.storageKey)
    #expect(preferences.loadShortcut() == .defaultShortcut)
    #expect(defaults.data(forKey: ShortcutPreferences.storageKey) == corrupt)

    let invalid = KeyboardShortcut(keyCode: 17, modifiers: [.shift])
    let invalidData = try JSONEncoder().encode(invalid)
    defaults.set(invalidData, forKey: ShortcutPreferences.storageKey)
    #expect(preferences.loadShortcut() == .defaultShortcut)
    #expect(defaults.data(forKey: ShortcutPreferences.storageKey) == invalidData)
}

@Test("Invalid shortcut is not persisted")
func invalidShortcutIsNotPersisted() throws {
    let suiteName = "DichThatTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = ShortcutPreferences(defaults: defaults)

    #expect(throws: ShortcutPreferencesError.invalidShortcut(.requiresCommandControlOrOption)) {
        try preferences.saveShortcut(
            KeyboardShortcut(keyCode: 17, modifiers: [.shift])
        )
    }
    #expect(defaults.object(forKey: ShortcutPreferences.storageKey) == nil)
}
