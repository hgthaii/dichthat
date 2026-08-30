import AppKit
import ApplicationServices
import DichThatCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private final class AppearanceObserverView: NSView {
        var onAppearanceChange: ((NSAppearance) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onAppearanceChange?(effectiveAppearance)
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            onAppearanceChange?(effectiveAppearance)
        }
    }

    private var statusItem: NSStatusItem?
    private let appearanceObserver = AppearanceObserverView(frame: .zero)
    private let statusMenu = NSMenu()
    private var settingsController: SettingsWindowController?
    private let shortcutRegistrar = CarbonGlobalShortcutRegistrar()
    private let shortcutPreferences = ShortcutPreferences()
    private let appPreferences = AppPreferences()
    private let launchAtLoginService = LaunchAtLoginService()
    private let updateCoordinator = UpdateCoordinator()
    private var captureRequestState = CaptureRequestState()
    private var captureContext: SelectionTriggerContext?
    private var capturePreferredAnchor: SelectionAnchor?
    private var lastExternalTargetPID: pid_t?
    private var captureTask: Task<Void, Never>?
    private var translationRequestState = TranslationRequestState()
    private var translationReuseCache = TranslationReuseCache()
    private var translationTask: Task<Void, Never>?
    private var permissionRefreshTask: Task<Void, Never>?
    private var translationAvailabilityTask: Task<Void, Never>?
    private var translationPreparationTask: Task<Void, Never>?
    private var translationOnboardingPending = true
    private var lastKnownAccessibilityTrust = false
    private var isSettingsPresented = false
    private let translationSpeech = TranslationSpeechController()
    private let appleTranslationProvider = AppleTranslationProvider()
    private lazy var translationEngine = TranslationEngine(provider: appleTranslationProvider)
    private var isTerminating = false
    private var currentShortcut = KeyboardShortcut.defaultShortcut
    private var settingsState = SettingsState(
        accessibilityGranted: false,
        shortcutDisplay: KeyboardShortcut.defaultShortcut.displayText,
        showSelectionIcon: AppConfiguration.Features.selectionIconEnabled
            && AppPreferences.defaultShowSelectionIcon
    )
    private lazy var shortcutHandler: @MainActor () -> Void = { [weak self] in
        self?.shortcutDidFire()
    }
    private lazy var shortcutConfiguration = ShortcutConfiguration(
        registrar: shortcutRegistrar,
        preferences: shortcutPreferences
    )
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
        },
        shouldIgnoreOutsideClick: { [weak self] point in
            self?.statusButtonFrameContains(point) ?? false
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateCoordinator.onStateChange = { [weak self] state in
            self?.settingsController?.refresh(updateState: state)
        }
        updateCoordinator.start()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenu.delegate = self
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        appearanceObserver.onAppearanceChange = { [weak self] appearance in
            self?.refreshApplicationIcon(for: appearance)
        }
        if let button = item.button {
            button.addSubview(appearanceObserver)
            refreshApplicationIcon(for: button.effectiveAppearance)
        }

        let loadedShortcut = shortcutPreferences.loadShortcut()
        currentShortcut = loadedShortcut
        let accessibilityGranted = AXIsProcessTrusted()
        lastKnownAccessibilityTrust = accessibilityGranted
        settingsState = SettingsState(
            accessibilityGranted: accessibilityGranted,
            shortcutDisplay: loadedShortcut.displayText,
            showSelectionIcon: AppConfiguration.Features.selectionIconEnabled
                && appPreferences.loadShowSelectionIcon(),
            launchAtLoginEnabled: launchAtLoginService.isEnabled
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
                error: AppText.Settings.shortcutRegistrationFailed(error.displayText)
            )
        }
        if !accessibilityGranted {
            startPermissionRefreshPolling()
        }
        refreshTranslationLanguageAvailability(presentOnboardingIfMissing: true)
        settingsController?.refresh(state: settingsState)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshPermissionAndObservation()
        refreshTranslationLanguageAvailability()
        if !AXIsProcessTrusted() {
            startPermissionRefreshPolling()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshPermissionAndObservation()
    }

    private func configureStatusItemButton(
        _ button: NSStatusBarButton?,
        presentation: StatusButtonPresentation
    ) {
        guard let button else { return }
        let image = Bundle.main.url(
            forResource: AppConfiguration.Resources.statusItemTemplateName,
            withExtension: AppConfiguration.Resources.statusItemTemplateExtension
        ).flatMap(NSImage.init(contentsOf:))
        button.contentTintColor = nil
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
            button.title = AppIdentity.productName
        }
        button.toolTip = presentation.toolTip
        button.setAccessibilityLabel(presentation.accessibilityLabel)
    }

    private func refreshApplicationIcon(for appearance: NSAppearance) {
        translationPanel.updateAppearance(appearance)
        guard let image = AdaptiveAppIcon.image(for: appearance) else { return }
        NSApplication.shared.applicationIconImage = image
    }

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        permissionRefreshTask?.cancel()
        translationAvailabilityTask?.cancel()
        cancelTranslationLanguagePreparation()
        cancelTranslation(hidePanel: true)
        selectionObservation.stop()
        shortcutRegistrar.unregister()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        permissionRefreshTask?.cancel()
        translationAvailabilityTask?.cancel()
        cancelTranslationLanguagePreparation()
        captureTask?.cancel()
        captureTask = nil
        captureContext = nil
        capturePreferredAnchor = nil
        captureRequestState.cancelForImmediateTermination()
        cancelTranslation(hidePanel: true)
        selectionObservation.stop()
        shortcutRegistrar.unregister()
        return .terminateNow
    }

    @objc private func quit() {
        statusMenu.cancelTracking()
        cancelTranslationLanguagePreparation()
        NSApplication.shared.terminate(nil)
    }

    @objc private func grantAccessibilityFromMenu() {
        requestAccessibilityPermission()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            dismissTranslation()
            refreshPermissionAndObservation()
            statusMenu.appearance = AdaptiveAppIcon.systemAppearance(
                fallback: NSApplication.shared.effectiveAppearance
            )
            statusItem?.menu = statusMenu
            sender.performClick(nil)
            statusItem?.menu = nil
            return
        }
        let anchor = statusButtonAnchor(sender)
        if translationPanel.isVisible {
            dismissTranslation()
            return
        }
        guard settingsState.translationLanguagesReady else {
            return
        }
        cancelTranslation(hidePanel: true)
        translationPanel.showInput(anchor: anchor) { [weak self] text in
            self?.menuBarInputChanged(text, anchor: anchor)
        }
    }

    @objc private func showSettings() {
        presentSettings(showAbout: false)
    }

    private func presentSettings(showAbout: Bool) {
        refreshPermissionAndObservation()
        refreshTranslationLanguageAvailability()
        if settingsController == nil {
            settingsController = SettingsWindowController(
                onGrantPermission: { [weak self] in
                    self?.requestAccessibilityPermission()
                },
                onPrepareTranslationLanguages: { [weak self] in
                    self?.prepareTranslationLanguages()
                },
                appVersion: AppMetadata.version,
                onCommitShortcut: { [weak self] candidate in
                    self?.acceptShortcut(candidate) ?? AppText.Errors.applicationUnavailable
                },
                onToggleSelectionIcon: { [weak self] isEnabled in
                    self?.setShowSelectionIcon(isEnabled)
                },
                onToggleLaunchAtLogin: { [weak self] isEnabled in
                    self?.setLaunchAtLogin(isEnabled)
                },
                onCheckForUpdates: { [weak self] in
                    self?.updateCoordinator.checkForUpdates()
                },
                onInstallUpdate: { [weak self] in
                    self?.updateCoordinator.installAvailableUpdate()
                },
                onDismiss: { [weak self] in
                    self?.settingsDidDismiss()
                }
            )
        }
        if let hostView = settingsController?.translationPreparationHostView {
            appleTranslationProvider.attachBridge(to: hostView)
        }
        isSettingsPresented = true
        settingsController?.present(
            state: settingsState,
            updateState: updateCoordinator.state,
            showAbout: showAbout
        )
    }

    @objc private func checkForUpdatesFromMenu() {
        presentSettings(showAbout: true)
        updateCoordinator.checkForUpdates()
    }

    private func settingsDidDismiss() {
        guard isSettingsPresented else { return }
        isSettingsPresented = false
        cancelTranslationLanguagePreparation()
    }

    private func acceptShortcut(_ candidate: KeyboardShortcut) -> String? {
        guard settingsState.translationLanguagesReady else { return nil }
        switch shortcutConfiguration.accept(candidate, handler: shortcutHandler) {
        case let .success(shortcut):
            currentShortcut = shortcut
            settingsState.updateShortcut(display: shortcut.displayText)
            settingsController?.refresh(state: settingsState)
            return nil
        case let .failure(error):
            settingsState.updateShortcut(
                display: currentShortcut.displayText,
                error: AppText.Settings.shortcutUpdateFailed(error.displayText)
            )
            settingsController?.refresh(state: settingsState)
            return AppText.Settings.shortcutUnavailable(error.displayText)
        }
    }

    private func shortcutDidFire() {
        guard settingsState.translationLanguagesReady else {
            return
        }
        let application = NSWorkspace.shared.frontmostApplication
        let mouseLocation = NSEvent.mouseLocation
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let targetPID = SelectionTargetResolver.targetPID(
            frontmostPID: application?.processIdentifier,
            ownPID: ownPID,
            lastExternalPID: lastExternalTargetPID
        )
        beginSelectionCapture(context: SelectionTriggerContext(
            targetPID: targetPID,
            mouseAnchor: CapturePoint(x: mouseLocation.x, y: mouseLocation.y)
        ))
    }

    private func beginSelectionCapture(context: SelectionTriggerContext) {
        if let targetPID = context.targetPID,
           targetPID != ProcessInfo.processInfo.processIdentifier {
            lastExternalTargetPID = targetPID
        }
        cancelTranslation(hidePanel: true)
        capturePreferredAnchor = selectionObservation.currentSelectionAnchor(
            for: context.targetPID
        )
        refreshPermissionAndObservation()
        guard AXIsProcessTrusted() else {
            translationPanel.showFailure(
                AppText.Errors.accessibilityRequired,
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
                AppText.Errors.captureInProgress,
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
            let preferredAnchor = capturePreferredAnchor
            captureContext = nil
            capturePreferredAnchor = nil
            guard !replyToTermination, !isTerminating else {
                if replyToTermination {
                    NSApp.reply(toApplicationShouldTerminate: true)
                }
                return
            }
            switch result {
            case let .success(output):
                let resolvedOutput = SelectionCaptureOutput(
                    text: output.text,
                    method: output.method,
                    anchor: SelectionAnchorResolver.resolve(
                        captured: output.anchor,
                        observed: preferredAnchor
                    )
                )
                startTranslation(output: resolvedOutput)
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
        translationPanel.prepareForQuickTranslation()
        if let cached = translationReuseCache.output(for: output.text) {
            cancelTranslation(hidePanel: false)
            translationPanel.show(
                output: cached,
                anchor: output.anchor,
                availableVoiceCodes: translationSpeech.availableVoiceCodes(for: cached.source)
            )
            return
        }
        let requestID = translationRequestState.begin()
        let anchor = output.anchor
        let text = output.text
        translationPanel.showLoading(anchor: anchor)
        translationTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let result = await self.translationEngine.translate(text: text)
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
            refreshTranslationLanguageAvailability()
            translationReuseCache.store(output)
            translationPanel.show(
                output: output,
                anchor: anchor,
                availableVoiceCodes: translationSpeech.availableVoiceCodes(for: output.source)
            )
        case let .failure(error):
            if error == .translationUnavailable {
                settingsState.updateTranslationLanguagesReady(false)
                refreshTranslationLanguageAvailability(presentOnboardingIfMissing: true)
            }
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
        let permissionWasJustGranted = isTrusted && !lastKnownAccessibilityTrust
        lastKnownAccessibilityTrust = isTrusted
        let effect = settingsState.refreshPermission(granted: isTrusted)
        configureStatusItemButton(
            statusItem?.button,
            presentation: StatusMenuModel.buttonPresentation(
                accessibilityGranted: isTrusted
            )
        )
        rebuildStatusMenu(
            accessibilityGranted: isTrusted,
            translationLanguagesReady: settingsState.translationLanguagesReady
        )
        if permissionWasJustGranted {
            reactivateAccessibilityIntegrations()
        } else {
            applySelectionObservationEffect(effect)
        }
        settingsController?.refresh(state: settingsState)
    }

    private func refreshTranslationLanguageAvailability(
        presentOnboardingIfMissing: Bool = false
    ) {
        if presentOnboardingIfMissing {
            translationOnboardingPending = true
        }
        translationAvailabilityTask?.cancel()
        translationAvailabilityTask = Task { [weak self] in
            guard let self else { return }
            let isReady = await appleTranslationProvider.languagesAreReady()
            guard !Task.isCancelled, !isTerminating else { return }
            settingsState.updateTranslationLanguagesReady(isReady)
            rebuildStatusMenu(
                accessibilityGranted: lastKnownAccessibilityTrust,
                translationLanguagesReady: isReady
            )
            settingsController?.refresh(state: settingsState)
            translationAvailabilityTask = nil
            if isReady {
                translationOnboardingPending = false
            } else if translationOnboardingPending {
                translationOnboardingPending = false
                presentSettings(showAbout: false)
            }
        }
    }

    private func prepareTranslationLanguages() {
        guard !settingsState.translationLanguagesReady,
              translationPreparationTask == nil
        else { return }
        settingsState.updateTranslationLanguagePreparation(isPreparing: true)
        settingsController?.refresh(state: settingsState)
        translationPreparationTask = Task { [weak self] in
            guard let self else { return }
            let result = await appleTranslationProvider.prepareLanguages()
            guard !Task.isCancelled, !isTerminating else { return }
            translationPreparationTask = nil
            switch result {
            case .success:
                settingsState.updateTranslationLanguagesReady(true)
                rebuildStatusMenu(
                    accessibilityGranted: lastKnownAccessibilityTrust,
                    translationLanguagesReady: true
                )
            case .failure:
                settingsState.updateTranslationLanguagePreparation(
                    isPreparing: false,
                    error: AppText.Settings.translationLanguageDownloadFailed
                )
            }
            settingsController?.refresh(state: settingsState)
        }
    }

    private func cancelTranslationLanguagePreparation() {
        translationPreparationTask?.cancel()
        translationPreparationTask = nil
        appleTranslationProvider.cancelLanguagePreparation()
        guard !settingsState.translationLanguagesReady else { return }
        settingsState.updateTranslationLanguagePreparation(isPreparing: false)
        settingsController?.refresh(state: settingsState)
    }

    private func reactivateAccessibilityIntegrations() {
        permissionRefreshTask?.cancel()
        _ = AXUIElementCreateSystemWide()
        selectionObservation.stopForPreference()
        selectionObservation.startOrRefresh(presentsIcon: settingsState.showSelectionIcon)
    }

    private func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermissionAndObservation()
        startPermissionRefreshPolling()
    }

    private func rebuildStatusMenu(
        accessibilityGranted: Bool,
        translationLanguagesReady: Bool
    ) {
        statusMenu.removeAllItems()
        let models = StatusMenuModel.items(
            accessibilityGranted: accessibilityGranted,
            translationLanguagesReady: translationLanguagesReady
        )
        for (index, model) in models.enumerated() {
            if index > 0 {
                statusMenu.addItem(.separator())
            }
            let action: Selector
            let keyEquivalent: String
            switch model.action {
            case .grantAccessibility:
                action = #selector(grantAccessibilityFromMenu)
                keyEquivalent = ""
            case .checkForUpdates:
                action = #selector(checkForUpdatesFromMenu)
                keyEquivalent = ""
            case .settings:
                action = #selector(showSettings)
                keyEquivalent = ","
            case .quit:
                action = #selector(quit)
                keyEquivalent = "q"
            }
            let item = NSMenuItem(title: model.title, action: action, keyEquivalent: keyEquivalent)
            item.target = self
            statusMenu.addItem(item)
        }
    }

    private func statusButtonAnchor(_ button: NSStatusBarButton) -> SelectionAnchor {
        guard let window = button.window else {
            let point = NSEvent.mouseLocation
            return .mouse(CapturePoint(x: point.x, y: point.y))
        }
        let windowRect = button.convert(button.bounds, to: nil)
        let screenRect = window.convertToScreen(windowRect)
        return .mouse(CapturePoint(x: screenRect.midX, y: screenRect.minY))
    }

    private func statusButtonFrameContains(_ point: CapturePoint) -> Bool {
        guard let button = statusItem?.button, let window = button.window else { return false }
        let windowRect = button.convert(button.bounds, to: nil)
        let screenRect = window.convertToScreen(windowRect)
        return screenRect.contains(NSPoint(x: point.x, y: point.y))
    }

    private func menuBarInputChanged(_ text: String, anchor: SelectionAnchor) {
        translationTask?.cancel()
        translationTask = nil
        _ = translationRequestState.cancel()
        translationSpeech.stop()

        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            translationPanel.showInputPrompt(anchor: anchor)
            return
        }
        if let cached = translationReuseCache.output(for: normalized) {
            translationPanel.show(
                output: cached,
                anchor: anchor,
                availableVoiceCodes: translationSpeech.availableVoiceCodes(for: cached.source)
            )
            return
        }

        let requestID = translationRequestState.begin()
        translationTask = Task.detached(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(
                nanoseconds: CoreConfiguration.MenuBarTranslation.debounceNanoseconds
            )
            guard !Task.isCancelled else { return }
            guard let self,
                  await self.showDebouncedLoading(requestID: requestID, anchor: anchor)
            else { return }
            let result = await self.translationEngine.translate(text: normalized)
            guard !Task.isCancelled else { return }
            await self.finishTranslation(requestID: requestID, anchor: anchor, result: result)
        }
    }

    private func showDebouncedLoading(
        requestID: UInt64,
        anchor: SelectionAnchor
    ) -> Bool {
        guard translationRequestState.activeRequestID == requestID else { return false }
        translationPanel.showLoading(anchor: anchor)
        return true
    }

    private func startPermissionRefreshPolling() {
        permissionRefreshTask?.cancel()
        permissionRefreshTask = Task { [weak self] in
            for _ in 0 ..< AppConfiguration.Accessibility.permissionRefreshAttempts {
                try? await Task.sleep(for: AppConfiguration.Accessibility.permissionRefreshInterval)
                guard !Task.isCancelled, let self else { return }
                self.refreshPermissionAndObservation()
                if AXIsProcessTrusted() { return }
            }
        }
    }

    private func setShowSelectionIcon(_ isEnabled: Bool) {
        appPreferences.saveShowSelectionIcon(isEnabled)
        let effect = settingsState.setShowSelectionIcon(isEnabled)
        applySelectionObservationEffect(effect)
        settingsController?.refresh(state: settingsState)
    }

    private func setLaunchAtLogin(_ isEnabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(isEnabled)
            settingsState.updateLaunchAtLogin(
                enabled: launchAtLoginService.isEnabled,
                error: launchAtLoginService.requiresApproval
                    ? AppText.Settings.startupApprovalRequired
                    : nil
            )
        } catch {
            settingsState.updateLaunchAtLogin(
                enabled: launchAtLoginService.isEnabled,
                error: AppText.Settings.startupError
            )
        }
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
            selectionObservation.startOrRefresh(presentsIcon: true)
        case .stopAndHide:
            if AXIsProcessTrusted() {
                selectionObservation.startOrRefresh(presentsIcon: false)
            } else {
                selectionObservation.stopForPreference()
            }
        case .remainStoppedPermissionRequired:
            selectionObservation.stopForPreference()
        }
    }
}
