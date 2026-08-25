public enum ClipboardCopyTiming: Equatable, Sendable {
    case firstWindow(changeCount: Int)
    case lateWindow(changeCount: Int)
    case timeout
}

public enum ClipboardRestoreDecision: Equatable, Sendable {
    case proceed
    case skipConcurrentChange
}

public enum ClipboardRestoreValidation: Equatable, Sendable {
    case restored
    case failed
    case raceDetected
}

public enum ClipboardTransaction {
    public static func classifyCopy(
        firstChange: Int?,
        lateChange: Int?
    ) -> ClipboardCopyTiming {
        if let firstChange { return .firstWindow(changeCount: firstChange) }
        if let lateChange { return .lateWindow(changeCount: lateChange) }
        return .timeout
    }

    public static func restoreDecision(
        observedCopyChangeCount: Int,
        currentChangeCount: Int
    ) -> ClipboardRestoreDecision {
        observedCopyChangeCount == currentChangeCount
            ? .proceed
            : .skipConcurrentChange
    }

    public static func validateRestore(
        snapshotWasEmpty: Bool,
        writeSucceeded: Bool?,
        preRestoreChangeCount: Int,
        clearChangeCount: Int,
        postRestoreChangeCount: Int
    ) -> ClipboardRestoreValidation {
        if !snapshotWasEmpty && writeSucceeded != true { return .failed }
        if clearChangeCount == preRestoreChangeCount { return .failed }
        if postRestoreChangeCount != clearChangeCount { return .raceDetected }
        return .restored
    }
}
