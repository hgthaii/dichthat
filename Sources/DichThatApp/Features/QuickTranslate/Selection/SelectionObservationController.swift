import AppKit
import ApplicationServices
import DichThatCore

private struct GlobalMouseEventSnapshot: Sendable {
    enum Kind: Sendable {
        case leftMouseDown
        case leftMouseDragged
        case leftMouseUp
        case scrollWheel
    }

    let kind: Kind
    let point: CapturePoint
    let targetPID: pid_t?
    let clickCount: Int

    init?(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown: kind = .leftMouseDown
        case .leftMouseDragged: kind = .leftMouseDragged
        case .leftMouseUp: kind = .leftMouseUp
        case .scrollWheel: kind = .scrollWheel
        default: return nil
        }
        let location = NSEvent.mouseLocation
        point = CapturePoint(x: location.x, y: location.y)
        clickCount = event.type == .leftMouseDown ? event.clickCount : 0
        targetPID = event.type == .leftMouseUp
            ? NSWorkspace.shared.frontmostApplication?.processIdentifier
            : nil
    }
}

private enum GlobalMouseMonitorBridge {
    static func install(
        handler: @escaping @MainActor @Sendable (GlobalMouseEventSnapshot) -> Void
    ) -> Any? {
        let callback: @Sendable (NSEvent) -> Void = { event in
            guard let snapshot = GlobalMouseEventSnapshot(event) else { return }
            DispatchQueue.main.async { [snapshot] in
                handler(snapshot)
            }
        }
        return NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .scrollWheel],
            handler: callback
        )
    }

    static func remove(_ token: Any) {
        NSEvent.removeMonitor(token)
    }
}

@MainActor
final class SelectionObservationController {
    enum Status: Equatable {
        case monitoring
        case permissionRequired
        case monitorUnavailable
    }

    private let observationQueue = DispatchQueue(
        label: AppConfiguration.SelectionObservation.queueLabel
    )
    private let statusChanged: @MainActor (Status) -> Void
    private let captureRequested: @MainActor (SelectionTriggerContext) -> Void
    private let selectionInvalidated: @MainActor () -> Void
    private lazy var iconPanel = SelectionIconPanelController { [weak self] in
        self?.iconClicked()
    }
    private var state = SelectionObservationState()
    private var monitorLifecycle = SelectionMonitorLifecycleState()
    private var globalMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var hideTimer: Timer?
    private var lastObservedAnchor: SelectionAnchor?
    private var lastObservedTargetPID: pid_t?
    private var pendingSuppressedSelectionAnchor: CapturePoint?
    private var presentsSelectionIcon = true

    init(
        statusChanged: @escaping @MainActor (Status) -> Void,
        captureRequested: @escaping @MainActor (SelectionTriggerContext) -> Void,
        selectionInvalidated: @escaping @MainActor () -> Void
    ) {
        self.statusChanged = statusChanged
        self.captureRequested = captureRequested
        self.selectionInvalidated = selectionInvalidated
    }

    func startOrRefresh(presentsIcon: Bool = true) {
        presentsSelectionIcon = presentsIcon
        installActivationObserverIfNeeded()
        apply(monitorLifecycle.refresh(isTrusted: AXIsProcessTrusted()))
    }

    private func installGlobalMonitor() {
        guard globalMonitor == nil else {
            apply([monitorLifecycle.monitorInstallationCompleted(success: true)])
            return
        }
        globalMonitor = GlobalMouseMonitorBridge.install { [weak self] snapshot in
            self?.handle(snapshot)
        }
        apply([monitorLifecycle.monitorInstallationCompleted(success: globalMonitor != nil)])
    }

    func stop() {
        stop(notifySelectionInvalidation: true)
    }

    func stopForPreference() {
        stop(notifySelectionInvalidation: false)
    }

    private func stop(notifySelectionInvalidation: Bool) {
        removeGlobalMonitor()
        monitorLifecycle.reset()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        activationObserver = nil
        invalidatePresentation(notifySelectionInvalidation: notifySelectionInvalidation)
    }

    private func handle(_ event: GlobalMouseEventSnapshot) {
        switch event.kind {
        case .leftMouseDown:
            invalidatePresentation()
            state.mouseDown(at: event.point, clickCount: event.clickCount)
            if event.clickCount > 1 {
                pendingSuppressedSelectionAnchor = event.point
            }
        case .leftMouseDragged:
            state.mouseDragged(to: event.point)
        case .leftMouseUp:
            let context = SelectionTriggerContext(
                targetPID: event.targetPID,
                mouseAnchor: event.point
            )
            guard let request = state.mouseUp(context: context) else {
                if pendingSuppressedSelectionAnchor != nil {
                    lastObservedAnchor = .mouse(event.point)
                    lastObservedTargetPID = context.targetPID
                    pendingSuppressedSelectionAnchor = nil
                }
                return
            }
            // Preserve the actual selection gesture endpoint immediately. AX may later
            // refine this to text bounds, but must never replace it with the cursor's
            // position at shortcut time.
            lastObservedAnchor = .mouse(context.mouseAnchor)
            lastObservedTargetPID = context.targetPID
            observationQueue.async { [weak self] in
                let output = AXSelectionCapture().capture(
                    frontmostPID: context.targetPID,
                    mouseAnchor: context.mouseAnchor
                )
                let result: SelectionObservationResult
                switch output?.anchor {
                case let .bounds(bounds):
                    result = .validBounds(bounds)
                case .mouse:
                    result = .validMouse
                case nil:
                    result = .unavailable
                }
                DispatchQueue.main.async { [weak self] in
                    self?.finish(request: request, result: result)
                }
            }
        case .scrollWheel:
            invalidatePresentation()
        }
    }

    private func finish(
        request: SelectionObservationState.Request,
        result: SelectionObservationResult
    ) {
        guard let presentation = state.complete(request: request, result: result) else { return }
        // Keep the gesture endpoint for Quick Translate. Certain browser/web-view
        // Accessibility implementations return selected-range bounds relative to
        // their content area rather than the global display, which can incorrectly
        // move the popup to x = 0 or onto another monitor. The mouse-up point is
        // already in AppKit's global screen coordinates and remains attached to
        // the selected text.
        lastObservedAnchor = .mouse(presentation.context.mouseAnchor)
        lastObservedTargetPID = presentation.context.targetPID
        guard presentsSelectionIcon else { return }
        iconPanel.show(presentation: presentation)
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: AppConfiguration.SelectionIcon.autoHideInterval,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.state.timeout(generation: presentation.generation) {
                    self.iconPanel.hide()
                }
            }
        }
    }

    private func iconClicked() {
        guard let context = state.consumeClick() else { return }
        hideTimer?.invalidate()
        iconPanel.hide()
        captureRequested(context)
    }

    private func invalidatePresentation(notifySelectionInvalidation: Bool = true) {
        hideTimer?.invalidate()
        hideTimer = nil
        state.invalidate()
        lastObservedAnchor = nil
        lastObservedTargetPID = nil
        pendingSuppressedSelectionAnchor = nil
        iconPanel.hide()
        if notifySelectionInvalidation {
            selectionInvalidated()
        }
    }

    func currentSelectionAnchor(for targetPID: pid_t?) -> SelectionAnchor? {
        guard targetPID == lastObservedTargetPID else { return nil }
        return lastObservedAnchor
    }

    private func removeGlobalMonitor() {
        if let globalMonitor {
            GlobalMouseMonitorBridge.remove(globalMonitor)
        }
        globalMonitor = nil
    }

    private func apply(_ actions: [SelectionMonitorLifecycleAction]) {
        for action in actions {
            switch action {
            case .installMonitor:
                installGlobalMonitor()
            case .removeMonitor:
                removeGlobalMonitor()
                invalidatePresentation()
            case .reportMonitoring:
                statusChanged(.monitoring)
            case .reportPermissionRequired:
                invalidatePresentation()
                statusChanged(.permissionRequired)
            case .reportMonitorUnavailable:
                statusChanged(.monitorUnavailable)
            }
        }
    }

    private func installActivationObserverIfNeeded() {
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let activatedPID = (
                notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
            )?.processIdentifier
            Task { @MainActor [weak self] in
                guard activatedPID != ProcessInfo.processInfo.processIdentifier else { return }
                self?.invalidatePresentation()
                self?.startOrRefresh(presentsIcon: self?.presentsSelectionIcon ?? true)
            }
        }
    }
}
