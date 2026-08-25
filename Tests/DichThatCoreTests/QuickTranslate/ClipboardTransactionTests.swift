import Testing
@testable import DichThatCore

@Test("Clipboard transaction covers timing and guarded restoration")
func clipboardTransactionDecisions() {
    #expect(ClipboardTransaction.classifyCopy(firstChange: 2, lateChange: nil) == .firstWindow(changeCount: 2))
    #expect(ClipboardTransaction.classifyCopy(firstChange: nil, lateChange: 3) == .lateWindow(changeCount: 3))
    #expect(ClipboardTransaction.classifyCopy(firstChange: nil, lateChange: nil) == .timeout)
    #expect(ClipboardTransaction.restoreDecision(
        observedCopyChangeCount: 4,
        currentChangeCount: 5
    ) == .skipConcurrentChange)
}

@Test("Nonempty and empty snapshots restore normally")
func normalAndEmptyRestore() {
    #expect(ClipboardTransaction.validateRestore(
        snapshotWasEmpty: false,
        writeSucceeded: true,
        preRestoreChangeCount: 10,
        clearChangeCount: 11,
        postRestoreChangeCount: 11
    ) == .restored)
    #expect(ClipboardTransaction.validateRestore(
        snapshotWasEmpty: true,
        writeSucceeded: nil,
        preRestoreChangeCount: 10,
        clearChangeCount: 11,
        postRestoreChangeCount: 11
    ) == .restored)
}

@Test("Write failure and post-restore race are typed")
func restoreFailuresAreTyped() {
    #expect(ClipboardTransaction.validateRestore(
        snapshotWasEmpty: false,
        writeSucceeded: false,
        preRestoreChangeCount: 10,
        clearChangeCount: 11,
        postRestoreChangeCount: 11
    ) == .failed)
    #expect(ClipboardTransaction.validateRestore(
        snapshotWasEmpty: false,
        writeSucceeded: true,
        preRestoreChangeCount: 10,
        clearChangeCount: 11,
        postRestoreChangeCount: 12
    ) == .raceDetected)
}
