import DichThatCore

private func localizedDisplayText(_ english: String, _ vietnamese: String) -> String {
    AppLanguage.current.localized(english: english, vietnamese: vietnamese)
}

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
        case .accessibilityPermissionMissing:
            return localizedDisplayText("Accessibility not granted", "Chưa cấp quyền Trợ năng")
        case .selectionUnavailable:
            return localizedDisplayText("Selection unavailable", "Không thể đọc nội dung được chọn")
        case .clipboardSnapshotUnavailable:
            return localizedDisplayText("Clipboard unavailable", "Không thể truy cập clipboard")
        case .clipboardCopyEventFailed:
            return localizedDisplayText("Couldn’t copy the selection", "Không thể sao chép nội dung được chọn")
        case .clipboardCopyTimeout:
            return localizedDisplayText("Copy timed out", "Sao chép quá thời gian")
        case .clipboardLateCopyCapturedTextUnavailable,
             .clipboardCapturedTextUnavailable:
            return localizedDisplayText("Copied text unavailable", "Không đọc được nội dung đã sao chép")
        case .clipboardRestoreSkippedConcurrentChange:
            return localizedDisplayText(
                "Clipboard changed; restore skipped",
                "Clipboard đã thay đổi nên không thể khôi phục"
            )
        case .clipboardRestoreFailed:
            return localizedDisplayText("Clipboard restore failed", "Khôi phục clipboard thất bại")
        case .clipboardRestoreRaceDetected:
            return localizedDisplayText("Clipboard changed while restoring", "Clipboard thay đổi khi khôi phục")
        }
    }
}

extension TranslationFailure {
    var displayText: String {
        switch self {
        case .emptyInput: return AppText.Errors.noText
        case let .inputTooLong(maximum): return AppText.Errors.inputTooLong(maximum: maximum)
        case .unsupportedLanguage: return AppText.Errors.supportedLanguages
        case .ambiguousLanguage: return AppText.Errors.ambiguousLanguage
        case .cancelled: return AppText.Errors.cancelled
        case .timedOut: return AppText.Errors.timedOut
        case .networkUnavailable: return AppText.Errors.serviceUnavailable
        case let .httpStatus(status): return AppText.Errors.serviceError(status: status)
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
        case .persistenceFailed: return AppText.ShortcutErrors.persistenceUnavailable
        case let .rollbackFailed(error):
            return localizedDisplayText("Rollback failed", "Khôi phục phím tắt thất bại")
                + " (\(error.displayText))"
        }
    }
}

extension KeyboardShortcut.ValidationError {
    var displayText: String {
        switch self {
        case .unsupportedModifiers:
            return AppText.ShortcutErrors.unsupportedModifiers
        case .requiresCommandControlOrOption:
            return AppText.ShortcutErrors.requiresPrimaryModifier
        case .unusableKeyCode:
            return AppText.ShortcutErrors.unusableKey
        }
    }
}

extension ShortcutRegistrationError {
    var displayText: String {
        switch self {
        case let .invalidShortcut(error): return error.displayText
        case let .eventHandlerInstallationFailed(status):
            return localizedDisplayText("Event handler error", "Lỗi xử lý phím tắt")
                + " (OSStatus \(status))"
        case let .hotKeyRegistrationFailed(status):
            return localizedDisplayText("Hotkey registration error", "Lỗi đăng ký phím tắt")
                + " (OSStatus \(status))"
        }
    }
}
