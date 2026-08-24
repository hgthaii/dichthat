import AppKit
import ApplicationServices
import DichThatCore

@MainActor
final class ClipboardSelectionCapture {
    func capture(mouseAnchor: CapturePoint) async -> Result<SelectionCaptureOutput, SelectionCaptureError> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityPermissionMissing)
        }

        let pasteboard = NSPasteboard.general
        let originalChangeCount = pasteboard.changeCount
        var snapshotItems: [NSPasteboardItem]
        if let items = pasteboard.pasteboardItems {
            snapshotItems = items
        } else if let types = pasteboard.types, !types.isEmpty {
            return .failure(.clipboardSnapshotUnavailable)
        } else {
            snapshotItems = []
        }
        guard pasteboard.changeCount == originalChangeCount else {
            snapshotItems.removeAll(keepingCapacity: false)
            return .failure(.clipboardSnapshotUnavailable)
        }

        var capturedText: String?
        defer {
            capturedText = nil
            snapshotItems.removeAll(keepingCapacity: false)
        }

        guard await postCommandCopy() else {
            return .failure(.clipboardCopyEventFailed)
        }
        let firstChange = await waitForChange(
            after: originalChangeCount,
            pasteboard: pasteboard,
            seconds: AppConfiguration.Clipboard.firstCopyWindow
        )
        let lateChange = firstChange == nil
            ? await waitForChange(
                after: originalChangeCount,
                pasteboard: pasteboard,
                seconds: AppConfiguration.Clipboard.lateCopyWindow
            )
            : nil
        let timing = ClipboardTransaction.classifyCopy(
            firstChange: firstChange,
            lateChange: lateChange
        )
        let observedCopyChangeCount: Int
        let method: SelectionCaptureMethod
        switch timing {
        case let .firstWindow(changeCount):
            observedCopyChangeCount = changeCount
            method = .clipboard
        case let .lateWindow(changeCount):
            observedCopyChangeCount = changeCount
            method = .clipboardLateCopy
        case .timeout:
            return .failure(.clipboardCopyTimeout)
        }

        capturedText = pasteboard.string(forType: .string)
        let text = capturedText.flatMap { $0.isEmpty ? nil : $0 }
        let currentChangeCount = pasteboard.changeCount
        guard ClipboardTransaction.restoreDecision(
            observedCopyChangeCount: observedCopyChangeCount,
            currentChangeCount: currentChangeCount
        ) == .proceed else {
            return .failure(.clipboardRestoreSkippedConcurrentChange)
        }

        let snapshotWasEmpty = snapshotItems.isEmpty
        let clearChangeCount = pasteboard.clearContents()
        let writeSucceeded: Bool? = snapshotWasEmpty ? nil : pasteboard.writeObjects(snapshotItems)
        let validation = ClipboardTransaction.validateRestore(
            snapshotWasEmpty: snapshotWasEmpty,
            writeSucceeded: writeSucceeded,
            preRestoreChangeCount: currentChangeCount,
            clearChangeCount: clearChangeCount,
            postRestoreChangeCount: pasteboard.changeCount
        )
        switch validation {
        case .failed:
            return .failure(.clipboardRestoreFailed)
        case .raceDetected:
            return .failure(.clipboardRestoreRaceDetected)
        case .restored:
            break
        }

        guard let text else {
            return .failure(method == .clipboardLateCopy
                ? .clipboardLateCopyCapturedTextUnavailable
                : .clipboardCapturedTextUnavailable)
        }
        return .success(SelectionCaptureOutput(
            text: text,
            method: method,
            anchor: .mouse(mouseAnchor)
        ))
    }

    private func postCommandCopy() async -> Bool {
        guard AXIsProcessTrusted(),
              let down = CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(AppConfiguration.Clipboard.copyKeyCode),
                keyDown: true
              ),
              let up = CGEvent(
                keyboardEventSource: nil,
                virtualKey: CGKeyCode(AppConfiguration.Clipboard.copyKeyCode),
                keyDown: false
              )
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        try? await Task.sleep(
            nanoseconds: AppConfiguration.Clipboard.copyKeyUpDelayNanoseconds
        )
        up.post(tap: .cghidEventTap)
        return true
    }

    private func waitForChange(
        after changeCount: Int,
        pasteboard: NSPasteboard,
        seconds: CFTimeInterval
    ) async -> Int? {
        let deadline = CFAbsoluteTimeGetCurrent() + seconds
        while CFAbsoluteTimeGetCurrent() < deadline {
            let current = pasteboard.changeCount
            if current != changeCount { return current }
            try? await Task.sleep(
                nanoseconds: AppConfiguration.Clipboard.pollIntervalNanoseconds
            )
        }
        return nil
    }
}
