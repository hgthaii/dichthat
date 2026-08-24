public struct SelectionTriggerContext: Equatable, Sendable {
    public let targetPID: Int32?
    public let mouseAnchor: CapturePoint

    public init(targetPID: Int32?, mouseAnchor: CapturePoint) {
        self.targetPID = targetPID
        self.mouseAnchor = mouseAnchor
    }
}

public enum SelectionObservationResult: Equatable, Sendable {
    case validBounds(CaptureBounds)
    case validMouse
    case heuristicMouse
    case unavailable
}

public struct SelectionIconPresentation: Equatable, Sendable {
    public let generation: UInt64
    public let context: SelectionTriggerContext
    public let anchor: SelectionAnchor
}

public enum SelectionMonitorLifecycleAction: Equatable, Sendable {
    case installMonitor
    case removeMonitor
    case reportMonitoring
    case reportPermissionRequired
    case reportMonitorUnavailable
}

public struct SelectionMonitorLifecycleState: Equatable, Sendable {
    public private(set) var isTrusted = false
    public private(set) var monitorInstalled = false

    public init() {}

    public mutating func refresh(isTrusted: Bool) -> [SelectionMonitorLifecycleAction] {
        self.isTrusted = isTrusted
        guard isTrusted else {
            let shouldRemove = monitorInstalled
            monitorInstalled = false
            return shouldRemove
                ? [.removeMonitor, .reportPermissionRequired]
                : [.reportPermissionRequired]
        }
        return monitorInstalled ? [.reportMonitoring] : [.installMonitor]
    }

    public mutating func monitorInstallationCompleted(
        success: Bool
    ) -> SelectionMonitorLifecycleAction {
        monitorInstalled = success
        return success ? .reportMonitoring : .reportMonitorUnavailable
    }

    public mutating func reset() {
        isTrusted = false
        monitorInstalled = false
    }
}

public struct SelectionObservationState: Equatable, Sendable {
    public struct Request: Equatable, Sendable {
        public let generation: UInt64
        public let context: SelectionTriggerContext
    }

    private var generation: UInt64 = 0
    private var mouseDownPoint: CapturePoint?
    private var dragQualified = false
    private var gestureSuppressed = false
    public private(set) var presentation: SelectionIconPresentation?

    public init() {}

    public mutating func mouseDown(at point: CapturePoint, clickCount: Int = 1) {
        invalidate()
        guard clickCount <= 1 else {
            gestureSuppressed = true
            return
        }
        mouseDownPoint = point
        dragQualified = false
    }

    public mutating func mouseDragged(to point: CapturePoint) {
        guard !gestureSuppressed, let start = mouseDownPoint else { return }
        let dx = point.x - start.x
        let dy = point.y - start.y
        if (dx * dx + dy * dy).squareRoot()
            >= CoreConfiguration.SelectionObservation.minimumDragDistance {
            dragQualified = true
        }
    }

    public mutating func mouseUp(context: SelectionTriggerContext) -> Request? {
        defer {
            mouseDownPoint = nil
            dragQualified = false
            gestureSuppressed = false
        }
        guard !gestureSuppressed, dragQualified else { return nil }
        generation &+= 1
        presentation = nil
        return Request(generation: generation, context: context)
    }

    public mutating func complete(
        request: Request,
        result: SelectionObservationResult
    ) -> SelectionIconPresentation? {
        guard request.generation == generation else { return nil }
        let anchor: SelectionAnchor
        switch result {
        case let .validBounds(bounds):
            anchor = .bounds(bounds)
        case .validMouse:
            anchor = .mouse(request.context.mouseAnchor)
        case .heuristicMouse, .unavailable:
            presentation = nil
            return nil
        }
        let value = SelectionIconPresentation(
            generation: request.generation,
            context: request.context,
            anchor: anchor
        )
        presentation = value
        return value
    }

    public mutating func timeout(generation expectedGeneration: UInt64) -> Bool {
        guard generation == expectedGeneration,
              presentation?.generation == expectedGeneration
        else { return false }
        invalidate()
        return true
    }

    public mutating func consumeClick() -> SelectionTriggerContext? {
        guard let context = presentation?.context else { return nil }
        invalidate()
        return context
    }

    public mutating func invalidate() {
        generation &+= 1
        presentation = nil
        mouseDownPoint = nil
        dragQualified = false
        gestureSuppressed = false
    }
}

public enum SelectionIconGeometry {
    public static func appKitBounds(
        fromQuartz bounds: CaptureBounds,
        mainDisplayHeight: Double
    ) -> CaptureBounds {
        CaptureBounds(
            x: bounds.x,
            y: mainDisplayHeight - bounds.y - bounds.height,
            width: bounds.width,
            height: bounds.height
        )
    }

    public static func iconOrigin(
        anchor: SelectionAnchor,
        mainDisplayHeight: Double,
        iconSize: Double,
        offset: Double,
        visibleFrame: CaptureBounds
    ) -> CapturePoint {
        let proposed: CapturePoint
        switch anchor {
        case let .bounds(quartzBounds):
            let bounds = appKitBounds(fromQuartz: quartzBounds, mainDisplayHeight: mainDisplayHeight)
            proposed = CapturePoint(
                x: bounds.x + bounds.width + offset,
                y: bounds.y + bounds.height / 2 - iconSize / 2
            )
        case let .mouse(point):
            proposed = CapturePoint(x: point.x + offset, y: point.y - iconSize / 2)
        }
        return CapturePoint(
            x: min(max(proposed.x, visibleFrame.x), visibleFrame.x + visibleFrame.width - iconSize),
            y: min(max(proposed.y, visibleFrame.y), visibleFrame.y + visibleFrame.height - iconSize)
        )
    }
}
