import DichThatCore

extension SelectionCaptureMethod {
    var displayText: String {
        switch self {
        case .axStandard: return "AX"
        case .axTextMarker: return "AX marker"
        case .clipboard: return "clipboard"
        case .clipboardLateCopy: return "clipboard late"
        }
    }
}

extension SelectionCaptureError {
    var displayText: String {
        switch self {
        case .accessibilityPermissionMissing: return "Accessibility not granted"
        case .selectionUnavailable: return "selection unavailable"
        case .clipboardSnapshotUnavailable: return "clipboard snapshot unavailable"
        case .clipboardCopyEventFailed: return "copy event failed"
        case .clipboardCopyTimeout: return "copy timeout"
        case .clipboardLateCopyCapturedTextUnavailable: return "late copy had no text"
        case .clipboardCapturedTextUnavailable: return "copied text unavailable"
        case .clipboardRestoreSkippedConcurrentChange: return "clipboard changed; restore skipped"
        case .clipboardRestoreFailed: return "clipboard restore failed"
        case .clipboardRestoreRaceDetected: return "clipboard restore race detected"
        }
    }
}

extension TranslationFailure {
    var displayText: String {
        switch self {
        case .emptyInput: return AppText.Errors.noText
        case let .inputTooLong(maximum): return "Selection exceeds \(maximum) Unicode scalars"
        case .unsupportedLanguage: return AppText.Errors.supportedLanguages
        case .ambiguousLanguage: return AppText.Errors.ambiguousLanguage
        case .cancelled: return AppText.Errors.cancelled
        case .timedOut: return AppText.Errors.timedOut
        case .networkUnavailable: return AppText.Errors.serviceUnavailable
        case let .httpStatus(status): return "Translation service error (\(status))"
        case .malformedResponse, .emptyTranslation: return AppText.Errors.invalidResponse
        case .unsupportedResponseLanguage: return AppText.Errors.unsupportedResponseLanguage
        case .sourceLanguageMismatch: return AppText.Errors.sourceLanguageChanged
        }
    }
}

extension ShortcutConfigurationError {
    var displayText: String {
        switch self {
        case let .invalidShortcut(error): return error.displayText
        case let .registration(error): return error.displayText
        case .persistenceFailed: return "preferences unavailable"
        case let .rollbackFailed(error): return "rollback failed (\(error.displayText))"
        }
    }
}

extension KeyboardShortcut.ValidationError {
    var displayText: String {
        switch self {
        case .unsupportedModifiers:
            return "Choose only Control, Option, Command, or Shift."
        case .requiresCommandControlOrOption:
            return "Choose at least Control, Option, or Command."
        case .unusableKeyCode:
            return "Choose one letter A–Z or number 0–9."
        }
    }
}

extension ShortcutRegistrationError {
    var displayText: String {
        switch self {
        case let .invalidShortcut(error): return error.displayText
        case let .eventHandlerInstallationFailed(status): return "event handler OSStatus \(status)"
        case let .hotKeyRegistrationFailed(status): return "hotkey OSStatus \(status)"
        }
    }
}
