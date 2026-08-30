import Foundation

/// Centralized AppKit layout, timing, and resource configuration.
enum AppConfiguration {
    enum Features {
        // Kept behind a flag while the selection gesture UX is refined.
        static let selectionIconEnabled = false
    }

    enum Resources {
        static let darkAppIconName = "AppIconDark"
        static let lightAppIconName = "AppIconLight"
        static let adaptiveAppIconExtension = "png"
        static let statusItemTemplateName = "StatusItemTemplate"
        static let statusItemTemplateExtension = "png"
        static let statusItemPointSize: CGFloat = 18
    }

    enum Accessibility {
        static let captureQueueLabel = "dev.hgthaii.dichthat.accessibility-capture"
        static let searchDuration: CFTimeInterval = 1.25
        static let captureTimeout: TimeInterval = 3
        static let maximumDepth = 12
        static let maximumNodes = 180
        static let maximumCalls = 360
        static let messagingTimeout: Float = 0.2
        static let permissionRefreshAttempts = 120
        static let permissionRefreshInterval = Duration.milliseconds(500)
    }

    enum Clipboard {
        static let firstCopyWindow: CFTimeInterval = 0.5
        static let lateCopyWindow: CFTimeInterval = 0.5
        static let copyKeyUpDelayNanoseconds: UInt64 = 20_000_000
        static let pollIntervalNanoseconds: UInt64 = 10_000_000
        static let copyKeyCode: UInt16 = 8
    }

    enum SelectionIcon {
        static let size: CGFloat = 32
        static let anchorOffset: CGFloat = 8
        static let autoHideInterval: TimeInterval = 5
    }

    enum SelectionObservation {
        static let queueLabel = "dev.hgthaii.dichthat.selection-observation"
    }

    enum TranslationPanel {
        static let initialWidth: CGFloat = 380
        static let initialHeight: CGFloat = 150
        static let cornerRadius: CGFloat = 12
        static let tailHeight: CGFloat = 10
        static let tailHalfWidth: CGFloat = 8
        static let tailInset: CGFloat = 26
        static let selectionClearance: CGFloat = 8
        static let contentSpacing: CGFloat = 8
        static let contentInset: CGFloat = 14
        static let contentWidthInsets: CGFloat = 28
        static let headerFontSize: CGFloat = 11
        static let inputFontSize: CGFloat = 15
        static let inputHeight: CGFloat = 28
        static let inputTextMinimumHeight: CGFloat = 20
        static let inputVerticalPadding: CGFloat = 8
        static let loadingFontSize: CGFloat = 14
        static let failureFontSize: CGFloat = 14
        static let compactSourceFontSize: CGFloat = 12
        static let compactResultFontSize: CGFloat = 16
        static let enrichedResultFontSize: CGFloat = 18
        static let unavailableVoiceFontSize: CGFloat = 11
        static let sourceWordFontSize: CGFloat = 21
        static let sourceWordSpacing: CGFloat = 2
        static let phoneticFontSize: CGFloat = 12
        static let pronunciationRowSpacing: CGFloat = 5
        static let sourceRowSpacing: CGFloat = 7
        static let meaningFontSize: CGFloat = 13
        static let exampleFontSize: CGFloat = 12
        static let meaningSpacing: CGFloat = 4
        static let synonymFontSize: CGFloat = 11
        static let translationFontSize: CGFloat = 13
        static let sectionFontSize: CGFloat = 11
        static let badgeFontSize: CGFloat = 10
        static let badgeHorizontalInset: CGFloat = 7
        static let badgeCornerRadius: CGFloat = 6
        static let badgeMinimumHeight: CGFloat = 20
        static let badgeBackgroundOpacity: CGFloat = 0.92
        static let badgeBorderOpacity: CGFloat = 0.34
        static let badgeBorderWidth: CGFloat = 0.5
        static let badgeShadowOpacity: Float = 0.18
        static let badgeShadowRadius: CGFloat = 3
        static let badgeShadowOffset = CGSize(width: 0, height: -1)
        static let minimumWidth: CGFloat = 280
        static let maximumWidth: CGFloat = 400
        static let maximumHeight: CGFloat = 520
        static let screenMargin: CGFloat = 40
        static let minimumHeight: CGFloat = 120
        static let minimumInputHeight: CGFloat = 66
    }

    enum Settings {
        static let windowWidth: CGFloat = 480
        static let windowHeight: CGFloat = 400
        static let contentInset: CGFloat = 24
        static let sectionSpacing: CGFloat = 18
        static let rowHeight: CGFloat = 64
        static let cardRadius: CGFloat = 10
        static let cardBorderWidth: CGFloat = 1
        static let permissionHeight: CGFloat = 54
        static let shortcutHeight: CGFloat = 112
        static let tabWidth: CGFloat = 74
        static let tabHeight: CGFloat = 28
        static let headerHeight: CGFloat = 76
        static let toggleWidth: CGFloat = 36
        static let toggleHeight: CGFloat = 20
        static let toggleInset: CGFloat = 2
        static let aboutIconSize: CGFloat = 52
        static let updateCardWidth: CGFloat = 360
        static let updateCardHeight: CGFloat = 52
    }
}
