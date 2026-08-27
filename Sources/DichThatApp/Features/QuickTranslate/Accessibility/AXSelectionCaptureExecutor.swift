import Foundation
import DichThatCore

/// Keeps potentially slow Accessibility IPC away from AppKit's main thread.
/// A timed-out request remains the only active probe until its system calls
/// return, preventing slow target apps from creating an unbounded queue.
final class AXSelectionCaptureExecutor: @unchecked Sendable {
    enum Result: Sendable {
        case completed(output: SelectionCaptureOutput?, selectionBounds: CaptureBounds?)
        case busy
        case timedOut
    }

    private final class Resolution: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Result, Never>?

        init(continuation: CheckedContinuation<Result, Never>) {
            self.continuation = continuation
        }

        func resolve(_ result: Result) {
            lock.lock()
            guard let continuation else {
                lock.unlock()
                return
            }
            self.continuation = nil
            lock.unlock()
            continuation.resume(returning: result)
        }
    }

    private let queue = DispatchQueue(
        label: AppConfiguration.Accessibility.captureQueueLabel,
        qos: .userInitiated
    )
    private let stateLock = NSLock()
    private var isCapturing = false

    func capture(
        frontmostPID: pid_t?,
        mouseAnchor: CapturePoint
    ) async -> Result {
        guard beginCapture() else { return .busy }

        return await withCheckedContinuation { continuation in
            let resolution = Resolution(continuation: continuation)
            queue.async { [self] in
                let capture = AXSelectionCapture()
                let output = capture.capture(
                    frontmostPID: frontmostPID,
                    mouseAnchor: mouseAnchor
                )
                let selectionBounds = output == nil
                    ? capture.selectionBounds(frontmostPID: frontmostPID)
                    : nil
                finishCapture()
                resolution.resolve(.completed(
                    output: output,
                    selectionBounds: selectionBounds
                ))
            }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + AppConfiguration.Accessibility.captureTimeout
            ) {
                resolution.resolve(.timedOut)
            }
        }
    }

    private func beginCapture() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !isCapturing else { return false }
        isCapturing = true
        return true
    }

    private func finishCapture() {
        stateLock.lock()
        isCapturing = false
        stateLock.unlock()
    }
}
