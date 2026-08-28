import Testing
@testable import DichThatCore

@Test("Turning selection icon off stops observation and preserves shortcut")
func disablingSelectionIconPreservesShortcut() {
    var state = SettingsState(
        accessibilityGranted: true,
        shortcutDisplay: "⌃⌥T",
        showSelectionIcon: true,
        selectionIconStatus: .monitoring
    )

    #expect(state.setShowSelectionIcon(false) == .stopAndHide)
    #expect(!state.showSelectionIcon)
    #expect(state.selectionIconStatus == .disabled)
    #expect(state.shortcutDisplay == "⌃⌥T")
}

@Test("Turning selection icon on resumes only with permission")
func enablingSelectionIconRequiresPermission() {
    var untrusted = SettingsState(
        accessibilityGranted: false,
        shortcutDisplay: "⌃⌥T",
        showSelectionIcon: false
    )
    #expect(
        untrusted.setShowSelectionIcon(true)
            == .remainStoppedPermissionRequired
    )
    #expect(untrusted.selectionIconStatus == .permissionRequired)

    var trusted = SettingsState(
        accessibilityGranted: true,
        shortcutDisplay: "⌃⌥T",
        showSelectionIcon: false
    )
    #expect(trusted.setShowSelectionIcon(true) == .startMonitoring)
    #expect(trusted.selectionIconStatus == .monitoring)
}

@Test("Permission refresh starts and stops monitoring deterministically")
func settingsPermissionRefresh() {
    var state = SettingsState(
        accessibilityGranted: false,
        shortcutDisplay: "⌃⌥T",
        showSelectionIcon: true
    )
    #expect(state.refreshPermission(granted: true) == .startMonitoring)
    #expect(state.accessibilityGranted)
    #expect(state.refreshPermission(granted: false) == .stopAndHide)
    #expect(!state.accessibilityGranted)
    #expect(state.selectionIconStatus == .permissionRequired)
}

@Test("Disabled preference stays stopped across permission refresh")
func disabledPreferenceStaysStopped() {
    var state = SettingsState(
        accessibilityGranted: false,
        shortcutDisplay: "⌃⌥T",
        showSelectionIcon: false
    )
    #expect(state.refreshPermission(granted: true) == .stopAndHide)
    #expect(state.selectionIconStatus == .disabled)
    #expect(state.shortcutDisplay == "⌃⌥T")
}

@Test("Launch at login state preserves the service result and error")
func launchAtLoginState() {
    var state = SettingsState(
        accessibilityGranted: true,
        shortcutDisplay: "⌃⌥T",
        showSelectionIcon: true
    )
    state.updateLaunchAtLogin(enabled: true)
    #expect(state.launchAtLoginEnabled)
    #expect(state.launchAtLoginError == nil)
    state.updateLaunchAtLogin(enabled: false, error: AppText.Settings.startupError)
    #expect(!state.launchAtLoginEnabled)
    #expect(state.launchAtLoginError == AppText.Settings.startupError)
}

@Test("Translation language readiness can refresh without changing other settings")
func translationLanguageReadiness() {
    var state = SettingsState(
        accessibilityGranted: true,
        shortcutDisplay: "⌃⌥T",
        showSelectionIcon: false
    )
    #expect(!state.translationLanguagesReady)
    state.updateTranslationLanguagesReady(true)
    #expect(state.translationLanguagesReady)
    #expect(state.shortcutDisplay == "⌃⌥T")
    #expect(state.accessibilityGranted)
}

@Test("Translation language preparation clears after models become ready")
func translationLanguagePreparation() {
    var state = SettingsState(
        accessibilityGranted: false,
        shortcutDisplay: "⌃⌥T",
        showSelectionIcon: false
    )
    state.updateTranslationLanguagePreparation(isPreparing: true)
    #expect(state.isPreparingTranslationLanguages)
    state.updateTranslationLanguagesReady(true)
    #expect(!state.isPreparingTranslationLanguages)
    #expect(state.translationLanguagesError == nil)
}
