public struct CapturePoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CaptureBounds: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum SelectionAnchor: Equatable, Sendable {
    case bounds(CaptureBounds)
    case mouse(CapturePoint)
}

public enum SelectionCaptureMethod: String, Equatable, Sendable {
    case axStandard
    case axTextMarker
    case clipboard
    case clipboardLateCopy
}

public struct SelectionCaptureOutput: Equatable, Sendable {
    public let text: String
    public let method: SelectionCaptureMethod
    public let anchor: SelectionAnchor

    public init(text: String, method: SelectionCaptureMethod, anchor: SelectionAnchor) {
        self.text = text
        self.method = method
        self.anchor = anchor
    }

    public var characterCount: Int { text.count }
}

public enum SelectionCaptureError: Error, Equatable, Sendable {
    case accessibilityPermissionMissing
    case selectionUnavailable
    case clipboardSnapshotUnavailable
    case clipboardCopyEventFailed
    case clipboardCopyTimeout
    case clipboardLateCopyCapturedTextUnavailable
    case clipboardCapturedTextUnavailable
    case clipboardRestoreSkippedConcurrentChange
    case clipboardRestoreFailed
    case clipboardRestoreRaceDetected
}
