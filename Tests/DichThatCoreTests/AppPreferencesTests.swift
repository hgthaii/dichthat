import Foundation
import Testing
@testable import DichThatCore

@Test("Selection icon preference defaults on without writing")
func selectionIconPreferenceDefaultsOn() {
    let suiteName = "dev.hgthaii.dichthat.tests.app-preferences.default"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = AppPreferences(defaults: defaults)

    #expect(preferences.loadShowSelectionIcon())
    #expect(defaults.object(forKey: AppPreferences.Keys.showSelectionIcon) == nil)
}

@Test("Corrupt selection icon preference falls back on without overwrite")
func corruptSelectionIconPreferenceFallsBack() {
    let suiteName = "dev.hgthaii.dichthat.tests.app-preferences.corrupt"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set("not-a-boolean", forKey: AppPreferences.Keys.showSelectionIcon)
    let preferences = AppPreferences(defaults: defaults)

    #expect(preferences.loadShowSelectionIcon())
    #expect(
        defaults.string(forKey: AppPreferences.Keys.showSelectionIcon)
            == "not-a-boolean"
    )
}

@Test("Accepted selection icon toggle persists")
func selectionIconPreferencePersists() {
    let suiteName = "dev.hgthaii.dichthat.tests.app-preferences.persisted"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = AppPreferences(defaults: defaults)

    preferences.saveShowSelectionIcon(false)
    #expect(!preferences.loadShowSelectionIcon())
    preferences.saveShowSelectionIcon(true)
    #expect(preferences.loadShowSelectionIcon())
}
