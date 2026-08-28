import ApplicationServices
import DichThatCore

@MainActor
final class SelectionCaptureService {
    private static let axCaptureExecutor = AXSelectionCaptureExecutor()
    private let clipboardCapture = ClipboardSelectionCapture()

    func capture(
        frontmostPID: pid_t?,
        mouseAnchor: CapturePoint
    ) async -> Result<SelectionCaptureOutput, SelectionCaptureError> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityPermissionMissing)
        }
        let accessibilityResult = await Self.axCaptureExecutor.capture(
            frontmostPID: frontmostPID,
            mouseAnchor: mouseAnchor
        )
        let selectionBounds: CaptureBounds?
        switch accessibilityResult {
        case let .completed(output, capturedBounds):
            if let output {
                return .success(SelectionCaptureOutput(
                    text: output.text,
                    method: output.method,
                    anchor: SelectionAnchorResolver.resolve(
                        captured: output.anchor,
                        observed: capturedBounds.map(SelectionAnchor.bounds)
                    )
                ))
            }
            selectionBounds = capturedBounds
        case .busy, .timedOut:
            return .failure(.selectionUnavailable)
        }

        if Task.isCancelled {
            return .failure(.selectionUnavailable)
        }
        let selectionAnchor = selectionBounds.map(SelectionAnchor.bounds)
        return await clipboardCapture.capture(
            mouseAnchor: mouseAnchor,
            preferredAnchor: selectionAnchor
        )
    }
}
