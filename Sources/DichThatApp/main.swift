import AppKit
import ApplicationServices
import DichThatCore

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsController: SettingsWindowController?
    private let shortcutRegistrar = CarbonGlobalShortcutRegistrar()
    private let shortcutPreferences = ShortcutPreferences()
    private let appPreferences = AppPreferences()
    private var captureRequestState = CaptureRequestState()
    private var captureContext: SelectionTriggerContext?
    private var captureTask: Task<Void, Never>?
    private var translationRequestState = TranslationRequestState()
    private var translationTask: Task<Void, Never>?
    private let translationSpeech = TranslationSpeechController()
    private var isTerminating = false
    private var currentShortcut = KeyboardShortcut.defaultShortcut
    private var settingsState = SettingsState(
        accessibilityGranted: false,
        shortcutDisplay: KeyboardShortcut.defaultShortcut.displayText,
        showSelectionIcon: AppPreferences.defaultShowSelectionIcon
    )
    private lazy var shortcutHandler: @MainActor () -> Void = { [weak self] in
        self?.shortcutDidFire()
    }
    private lazy var shortcutConfiguration = ShortcutConfiguration(
        registrar: shortcutRegistrar,
        preferences: shortcutPreferences
    )
    private lazy var shortcutRecorder = ShortcutRecorderWindowController { [weak self] candidate in
        self?.acceptShortcut(candidate) ?? "Application is unavailable."
    }
    private lazy var selectionObservation = SelectionObservationController(
        statusChanged: { [weak self] status in
            self?.selectionObservationStatusDidChange(status)
        },
        captureRequested: { [weak self] context in
            self?.beginSelectionCapture(context: context)
        },
        selectionInvalidated: { [weak self] in
            self?.selectionDidInvalidate()
        }
    )
    private lazy var translationPanel = TranslationPanelController(
        onDismiss: { [weak self] in
            self?.dismissTranslation()
        },
        onSpeak: { [weak self] content in
            self?.speakSource(content)
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        for model in StatusMenuModel.items {
            let action: Selector
            let keyEquivalent: String
            switch model.action {
            case .settings:
                action = #selector(showSettings)
                keyEquivalent = ","
            case .quit:
                action = #selector(quit)
                keyEquivalent = "q"
            }
            let menuItem = NSMenuItem(
                title: model.title,
                action: action,
                keyEquivalent: keyEquivalent
            )
            menuItem.target = self
            menu.addItem(menuItem)
        }
        item.menu = menu
        statusItem = item

        let loadedShortcut = shortcutPreferences.loadShortcut()
        currentShortcut = loadedShortcut
        settingsState = SettingsState(
            accessibilityGranted: AXIsProcessTrusted(),
            shortcutDisplay: loadedShortcut.displayText,
            showSelectionIcon: appPreferences.loadShowSelectionIcon()
        )
        refreshPermissionAndObservation()
        let result = shortcutConfiguration.start(handler: shortcutHandler)
        switch result {
        case let .success(shortcut):
            currentShortcut = shortcut
            settingsState.updateShortcut(display: shortcut.displayText)
        case let .failure(error):
            settingsState.updateShortcut(
                display: loadedShortcut.displayText,
                error: "Shortcut registration failed: \(error.displayText)"
            )
        }
        settingsController?.refresh(state: settingsState)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshPermissionAndObservation()
    }

    private func configureStatusItemButton(
        _ button: NSStatusBarButton?,
        presentation: StatusButtonPresentation
    ) {
        guard let button else { return }
        let image: NSImage?
        switch presentation.imageKind {
        case .brandTemplate:
            image = Bundle.main.url(
                forResource: AppConfiguration.Resources.statusItemTemplateName,
                withExtension: AppConfiguration.Resources.statusItemTemplateExtension
            ).flatMap(NSImage.init(contentsOf:))
            button.contentTintColor = nil
        case .accessibilityWarning:
            image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: presentation.accessibilityLabel
            )
            button.contentTintColor = .systemOrange
        }
        if let image {
            image.isTemplate = true
            image.size = NSSize(
                width: AppConfiguration.Resources.statusItemPointSize,
                height: AppConfiguration.Resources.statusItemPointSize
            )
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
        } else {
            button.image = nil
            button.title = presentation.imageKind == .accessibilityWarning
                ? "⚠︎"
                : AppIdentity.productName
        }
        button.toolTip = presentation.toolTip
        button.setAccessibilityLabel(presentation.accessibilityLabel)
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        cancelTranslation(hidePanel: true)
        selectionObservation.stop()
        shortcutRegistrar.unregister()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        cancelTranslation(hidePanel: true)
        switch captureRequestState.requestTermination() {
        case .terminateNow:
            return .terminateNow
        case .terminateLater:
            return .terminateLater
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func showSettings() {
        refreshPermissionAndObservation()
        if settingsController == nil {
            settingsController = SettingsWindowController(
                onGrantPermission: { [weak self] in
                    self?.requestAccessibilityPermission()
                },
                onOpenPermissionSettings: { [weak self] in
                    self?.openAccessibilitySettings()
                },
                onSetShortcut: { [weak self] in
                    self?.showShortcutRecorder()
                },
                onToggleSelectionIcon: { [weak self] isEnabled in
                    self?.setShowSelectionIcon(isEnabled)
                }
            )
        }
        settingsController?.present(state: settingsState)
    }

    @objc private func showShortcutRecorder() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        shortcutRecorder.present(currentShortcut: currentShortcut)
    }

    private func acceptShortcut(_ candidate: KeyboardShortcut) -> String? {
        switch shortcutConfiguration.accept(candidate, handler: shortcutHandler) {
        case let .success(shortcut):
            currentShortcut = shortcut
            settingsState.updateShortcut(display: shortcut.displayText)
            settingsController?.refresh(state: settingsState)
            return nil
        case let .failure(error):
            settingsState.updateShortcut(
                display: currentShortcut.displayText,
                error: "Shortcut update failed: \(error.displayText)"
            )
            settingsController?.refresh(state: settingsState)
            return "Could not use shortcut: \(error.displayText)"
        }
    }

    private func shortcutDidFire() {
        let application = NSWorkspace.shared.frontmostApplication
        let mouseLocation = NSEvent.mouseLocation
        beginSelectionCapture(context: SelectionTriggerContext(
            targetPID: application?.processIdentifier,
            mouseAnchor: CapturePoint(x: mouseLocation.x, y: mouseLocation.y)
        ))
    }

    private func beginSelectionCapture(context: SelectionTriggerContext) {
        cancelTranslation(hidePanel: true)
        refreshPermissionAndObservation()
        guard AXIsProcessTrusted() else {
            translationPanel.showFailure(
                "Accessibility access is required",
                anchor: .mouse(context.mouseAnchor)
            )
            return
        }

        let requestID: UInt64
        switch captureRequestState.begin() {
        case let .accepted(acceptedID):
            requestID = acceptedID
        case .ignoredActive:
            translationPanel.showFailure(
                "Selection capture is already in progress",
                anchor: .mouse(context.mouseAnchor)
            )
            return
        case .ignoredTerminationPending:
            return
        }

        captureContext = context

        captureTask = Task { [weak self] in
            guard let self else { return }
            let result = await SelectionCaptureService().capture(
                frontmostPID: context.targetPID,
                mouseAnchor: context.mouseAnchor
            )
            self.finishCapture(requestID: requestID, result: result)
        }
    }

    private func finishCapture(
        requestID: UInt64,
        result: Result<SelectionCaptureOutput, SelectionCaptureError>
    ) {
        captureTask = nil
        switch captureRequestState.complete(requestID: requestID) {
        case .stale:
            return
        case let .accepted(replyToTermination):
            let context = captureContext
            captureContext = nil
            guard !replyToTermination, !isTerminating else {
                if replyToTermination {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
                return
            }
            switch result {
            case let .success(output):
                startTranslation(output: output)
            case let .failure(error):
                if let context {
                    translationPanel.showFailure(
                        error.displayText,
                        anchor: .mouse(context.mouseAnchor)
                    )
                }
            }
        }
    }

    private func startTranslation(output: SelectionCaptureOutput) {
        let requestID = translationRequestState.begin()
        let anchor = output.anchor
        let text = output.text
        translationPanel.showLoading(anchor: anchor)
        translationTask = Task.detached(priority: .userInitiated) { [weak self] in
            let result = await TranslationEngine().translate(text: text)
            guard let self else { return }
            await self.finishTranslation(requestID: requestID, anchor: anchor, result: result)
        }
    }

    private func finishTranslation(
        requestID: UInt64,
        anchor: SelectionAnchor,
        result: Result<TranslationOutput, TranslationFailure>
    ) {
        let outcome: TranslationRequestState.Outcome
        switch result {
        case .success: outcome = .success
        case .failure: outcome = .failure
        }
        guard !isTerminating,
              translationRequestState.complete(requestID: requestID, outcome: outcome) == .accepted
        else { return }
        translationTask = nil
        switch result {
        case let .success(output):
            translationPanel.show(
                output: output,
                anchor: anchor,
                sourceVoiceAvailable: translationSpeech.isVoiceAvailable(for: output.source)
            )
        case let .failure(error):
            translationPanel.showFailure(error.displayText, anchor: anchor)
        }
    }

    private func dismissTranslation() {
        translationTask?.cancel()
        translationTask = nil
        translationRequestState.dismiss()
        translationSpeech.stop()
        translationPanel.hide()
    }

    private func cancelTranslation(hidePanel: Bool) {
        translationTask?.cancel()
        translationTask = nil
        _ = translationRequestState.cancel()
        translationSpeech.stop()
        if hidePanel {
            translationPanel.hide()
        }
    }

    private func selectionDidInvalidate() {
        translationTask?.cancel()
        translationTask = nil
        translationRequestState.invalidateSelection()
        translationSpeech.stop()
        translationPanel.hide()
    }

    private func speakSource(_ content: TranslationSpeechContent) {
        _ = translationSpeech.speak(content, target: .source)
    }

    private func refreshPermissionAndObservation() {
        let isTrusted = AXIsProcessTrusted()
        let effect = settingsState.refreshPermission(granted: isTrusted)
        configureStatusItemButton(
            statusItem?.button,
            presentation: StatusMenuModel.buttonPresentation(
                accessibilityGranted: isTrusted
            )
        )
        applySelectionObservationEffect(effect)
        settingsController?.refresh(state: settingsState)
    }

    private func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermissionAndObservation()
    }

    private func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func setShowSelectionIcon(_ isEnabled: Bool) {
        appPreferences.saveShowSelectionIcon(isEnabled)
        let effect = settingsState.setShowSelectionIcon(isEnabled)
        applySelectionObservationEffect(effect)
        settingsController?.refresh(state: settingsState)
    }

    private func selectionObservationStatusDidChange(
        _ status: SelectionObservationController.Status
    ) {
        let settingsStatus: SelectionIconSettingsStatus
        switch status {
        case .monitoring:
            settingsStatus = .monitoring
        case .permissionRequired:
            settingsStatus = .permissionRequired
        case .monitorUnavailable:
            settingsStatus = .monitorUnavailable
        }
        settingsState.updateSelectionIconStatus(settingsStatus)
        settingsController?.refresh(state: settingsState)
    }

    private func applySelectionObservationEffect(_ effect: SelectionObservationEffect) {
        switch effect {
        case .none:
            break
        case .startMonitoring:
            selectionObservation.startOrRefresh()
        case .stopAndHide, .remainStoppedPermissionRequired:
            selectionObservation.stopForPreference()
        }
    }
}

private extension SelectionCaptureMethod {
    var displayText: String {
        switch self {
        case .axStandard: return "AX"
        case .axTextMarker: return "AX marker"
        case .clipboard: return "clipboard"
        case .clipboardLateCopy: return "clipboard late"
        }
    }
}

private extension SelectionCaptureError {
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

private extension TranslationFailure {
    var displayText: String {
        switch self {
        case .emptyInput: return "No text to translate"
        case let .inputTooLong(maximum): return "Selection exceeds \(maximum) Unicode scalars"
        case .unsupportedLanguage: return "Only English and Vietnamese are supported"
        case .ambiguousLanguage: return "Couldn’t confidently detect English or Vietnamese"
        case .cancelled: return "Translation cancelled"
        case .timedOut: return "Translation timed out"
        case .networkUnavailable: return "Translation service unavailable"
        case let .httpStatus(status): return "Translation service error (\(status))"
        case .malformedResponse, .emptyTranslation: return "Translation response was invalid"
        case .unsupportedResponseLanguage: return "Detected language is not supported"
        case .sourceLanguageMismatch: return "Language detection changed; please try again"
        }
    }
}

private extension ShortcutConfigurationError {
    var displayText: String {
        switch self {
        case let .invalidShortcut(error):
            return "invalid (\(error))"
        case let .registration(error):
            return error.displayText
        case .persistenceFailed:
            return "preferences unavailable"
        case let .rollbackFailed(error):
            return "rollback failed (\(error.displayText))"
        }
    }
}

private extension ShortcutRegistrationError {
    var displayText: String {
        switch self {
        case let .invalidShortcut(error):
            return "invalid (\(error))"
        case let .eventHandlerInstallationFailed(status):
            return "event handler OSStatus \(status)"
        case let .hotKeyRegistrationFailed(status):
            return "hotkey OSStatus \(status)"
        }
    }
}

let application = NSApplication.shared
private let appDelegate = AppDelegate()
application.setActivationPolicy(.accessory)
application.delegate = appDelegate
application.run()
