public enum SelectionObservationEffect: Equatable, Sendable {
    case none
    case startMonitoring
    case stopAndHide
    case remainStoppedPermissionRequired
}

public enum SelectionIconSettingsStatus: Equatable, Sendable {
    case monitoring
    case permissionRequired
    case monitorUnavailable
    case disabled
}

public struct SettingsState: Equatable, Sendable {
    public private(set) var accessibilityGranted: Bool
    public private(set) var translationLanguagesReady: Bool
    public private(set) var isPreparingTranslationLanguages: Bool
    public private(set) var translationLanguagesError: String?
    public private(set) var shortcutDisplay: String
    public private(set) var shortcutError: String?
    public private(set) var inputShortcutDisplay: String
    public private(set) var inputShortcutError: String?
    public private(set) var showSelectionIcon: Bool
    public private(set) var selectionIconStatus: SelectionIconSettingsStatus
    public private(set) var launchAtLoginEnabled: Bool
    public private(set) var launchAtLoginError: String?

    public init(
        accessibilityGranted: Bool,
        translationLanguagesReady: Bool = false,
        isPreparingTranslationLanguages: Bool = false,
        translationLanguagesError: String? = nil,
        shortcutDisplay: String,
        shortcutError: String? = nil,
        inputShortcutDisplay: String = KeyboardShortcut.defaultInputShortcut.displayText,
        inputShortcutError: String? = nil,
        showSelectionIcon: Bool,
        selectionIconStatus: SelectionIconSettingsStatus = .disabled,
        launchAtLoginEnabled: Bool = false,
        launchAtLoginError: String? = nil
    ) {
        self.accessibilityGranted = accessibilityGranted
        self.translationLanguagesReady = translationLanguagesReady
        self.isPreparingTranslationLanguages = isPreparingTranslationLanguages
        self.translationLanguagesError = translationLanguagesError
        self.shortcutDisplay = shortcutDisplay
        self.shortcutError = shortcutError
        self.inputShortcutDisplay = inputShortcutDisplay
        self.inputShortcutError = inputShortcutError
        self.showSelectionIcon = showSelectionIcon
        self.selectionIconStatus = selectionIconStatus
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.launchAtLoginError = launchAtLoginError
    }

    public mutating func refreshPermission(
        granted: Bool
    ) -> SelectionObservationEffect {
        accessibilityGranted = granted
        guard showSelectionIcon else {
            selectionIconStatus = .disabled
            return .stopAndHide
        }
        selectionIconStatus = granted ? .monitoring : .permissionRequired
        return granted ? .startMonitoring : .stopAndHide
    }

    public mutating func updateShortcut(display: String, error: String? = nil) {
        shortcutDisplay = display
        shortcutError = error
    }

    public mutating func updateInputShortcut(display: String, error: String? = nil) {
        inputShortcutDisplay = display
        inputShortcutError = error
    }

    public mutating func updateTranslationLanguagesReady(_ isReady: Bool) {
        translationLanguagesReady = isReady
        if isReady {
            isPreparingTranslationLanguages = false
            translationLanguagesError = nil
        }
    }

    public mutating func updateTranslationLanguagePreparation(
        isPreparing: Bool,
        error: String? = nil
    ) {
        isPreparingTranslationLanguages = isPreparing
        translationLanguagesError = error
    }

    public mutating func setShowSelectionIcon(
        _ isEnabled: Bool
    ) -> SelectionObservationEffect {
        guard isEnabled != showSelectionIcon else { return .none }
        showSelectionIcon = isEnabled
        guard isEnabled else {
            selectionIconStatus = .disabled
            return .stopAndHide
        }
        selectionIconStatus = accessibilityGranted ? .monitoring : .permissionRequired
        return accessibilityGranted ? .startMonitoring : .remainStoppedPermissionRequired
    }

    public mutating func updateSelectionIconStatus(_ status: SelectionIconSettingsStatus) {
        selectionIconStatus = showSelectionIcon ? status : .disabled
    }

    public mutating func updateLaunchAtLogin(
        enabled: Bool,
        error: String? = nil
    ) {
        launchAtLoginEnabled = enabled
        launchAtLoginError = error
    }
}
