import AppKit
import ApplicationServices
import DichThatCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let statusMenu = NSMenu()
    private var settingsController: SettingsWindowController?
    private let shortcutRegistrar = CarbonGlobalShortcutRegistrar()
    private let shortcutPreferences = ShortcutPreferences()
    private let appPreferences = AppPreferences()
    private let launchAtLoginService = LaunchAtLoginService()
    private var captureRequestState = CaptureRequestState()
    private var captureContext: SelectionTriggerContext?
    private var capturePreferredAnchor: SelectionAnchor?
    private var lastExternalTargetPID: pid_t?
    private var captureTask: Task<Void, Never>?
    private var translationRequestState = TranslationRequestState()
    private var translationReuseCache = TranslationReuseCache()
    private var translationTask: Task<Void, Never>?
    private var permissionRefreshTask: Task<Void, Never>?
    private var lastKnownAccessibilityTrust = false
    private var isSettingsPresented = false
    private var permissionFlowPending = false
    private var permissionFlowObservedDeactivation = false
    private var relaunchScheduled = false
    private let translationSpeech = TranslationSpeechController()
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
        }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenu.delegate = self
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

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
                error: "Shortcut registration failed: \(error.displayText)"
            )
        }
        settingsController?.refresh(state: settingsState)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if permissionFlowPending, permissionFlowObservedDeactivation {
            schedulePermissionRelaunch()
            return
        }
        refreshPermissionAndObservation()
    }

    func applicationDidResignActive(_ notification: Notification) {
        if permissionFlowPending {
            permissionFlowObservedDeactivation = true
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

    func applicationWillTerminate(_ notification: Notification) {
        isTerminating = true
        permissionRefreshTask?.cancel()
        cancelTranslation(hidePanel: true)
        selectionObservation.stop()
        shortcutRegistrar.unregister()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        isTerminating = true
        cancelTranslation(hidePanel: true)
        if relaunchScheduled { return .terminateNow }
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

    @objc private func grantAccessibilityFromMenu() {
        requestAccessibilityPermission()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            dismissTranslation()
            refreshPermissionAndObservation()
            statusMenu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.height + 3),
                in: sender
            )
            return
        }
        let anchor = statusButtonAnchor(sender)
        if translationPanel.isVisible {
            dismissTranslation()
            return
        }
        cancelTranslation(hidePanel: true)
        translationPanel.showInput(anchor: anchor) { [weak self] text in
            self?.menuBarInputChanged(text, anchor: anchor)
        }
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
                onCommitShortcut: { [weak self] candidate in
                    self?.acceptShortcut(candidate) ?? AppText.Errors.applicationUnavailable
                },
                onToggleSelectionIcon: { [weak self] isEnabled in
                    self?.setShowSelectionIcon(isEnabled)
                },
                onToggleLaunchAtLogin: { [weak self] isEnabled in
                    self?.setLaunchAtLogin(isEnabled)
                },
                onCheckForUpdates: {
                    await UpdateChecker().check()
                },
                onDismiss: { [weak self] in
                    self?.settingsDidDismiss()
                }
            )
        }
        isSettingsPresented = true
        shortcutRegistrar.unregister()
        settingsController?.present(state: settingsState)
    }

    private func settingsDidDismiss() {
        guard isSettingsPresented else { return }
        isSettingsPresented = false
        guard !isTerminating else { return }
        switch shortcutConfiguration.start(handler: shortcutHandler) {
        case let .success(shortcut):
            currentShortcut = shortcut
            settingsState.updateShortcut(display: shortcut.displayText)
        case let .failure(error):
            settingsState.updateShortcut(
                display: currentShortcut.displayText,
                error: "Shortcut registration failed: \(error.displayText)"
            )
        }
        settingsController?.refresh(state: settingsState)
    }

    private func acceptShortcut(_ candidate: KeyboardShortcut) -> String? {
        switch shortcutConfiguration.accept(candidate, handler: shortcutHandler) {
        case let .success(shortcut):
            currentShortcut = shortcut
            settingsState.updateShortcut(display: shortcut.displayText)
            if isSettingsPresented {
                shortcutRegistrar.unregister()
            }
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
                sourceVoiceAvailable: translationSpeech.isVoiceAvailable(for: cached.source)
            )
            return
        }
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
            translationReuseCache.store(output)
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
        let permissionWasJustGranted = isTrusted && !lastKnownAccessibilityTrust
        lastKnownAccessibilityTrust = isTrusted
        let effect = settingsState.refreshPermission(granted: isTrusted)
        configureStatusItemButton(
            statusItem?.button,
            presentation: StatusMenuModel.buttonPresentation(
                accessibilityGranted: isTrusted
            )
        )
        rebuildStatusMenu(accessibilityGranted: isTrusted)
        applySelectionObservationEffect(effect)
        if permissionWasJustGranted {
            schedulePermissionRelaunch()
        }
        settingsController?.refresh(state: settingsState)
    }

    private func schedulePermissionRelaunch() {
        guard !relaunchScheduled else { return }
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            reactivateAccessibilityIntegrations()
            return
        }
        relaunchScheduled = true
        permissionFlowPending = false
        permissionRefreshTask?.cancel()
        cancelTranslation(hidePanel: true)
        selectionObservation.stopForPreference()
        shortcutRegistrar.unregister()
        let launcher = Process()
        launcher.executableURL = URL(fileURLWithPath: "/bin/sh")
        launcher.arguments = [
            "-c",
            "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.1; done; /usr/bin/open -g \"$2\"",
            "dichthat-relaunch",
            String(ProcessInfo.processInfo.processIdentifier),
            Bundle.main.bundleURL.path,
        ]
        do {
            try launcher.run()
            NSApplication.shared.terminate(nil)
        } catch {
            relaunchScheduled = false
            reactivateAccessibilityIntegrations()
        }
    }

    private func reactivateAccessibilityIntegrations() {
        _ = AXUIElementCreateSystemWide()
        selectionObservation.stopForPreference()
        selectionObservation.startOrRefresh(presentsIcon: settingsState.showSelectionIcon)

        switch shortcutConfiguration.start(handler: shortcutHandler) {
        case let .success(shortcut):
            currentShortcut = shortcut
            settingsState.updateShortcut(display: shortcut.displayText)
        case let .failure(error):
            settingsState.updateShortcut(
                display: currentShortcut.displayText,
                error: "Shortcut registration failed: \(error.displayText)"
            )
        }
    }

    private func requestAccessibilityPermission() {
        permissionFlowPending = true
        permissionFlowObservedDeactivation = false
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermissionAndObservation()
        startPermissionRefreshPolling()
    }

    private func openAccessibilitySettings() {
        permissionFlowPending = true
        permissionFlowObservedDeactivation = false
        NSWorkspace.shared.open(AppConfiguration.Accessibility.settingsURL)
        startPermissionRefreshPolling()
    }

    private func rebuildStatusMenu(accessibilityGranted: Bool) {
        statusMenu.removeAllItems()
        for model in StatusMenuModel.items(accessibilityGranted: accessibilityGranted) {
            let action: Selector
            let keyEquivalent: String
            switch model.action {
            case .grantAccessibility:
                action = #selector(grantAccessibilityFromMenu)
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
            if model.action == .grantAccessibility {
                statusMenu.addItem(.separator())
            }
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
                sourceVoiceAvailable: translationSpeech.isVoiceAvailable(for: cached.source)
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
            let result = await TranslationEngine().translate(text: normalized)
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
