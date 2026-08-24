import ApplicationServices
import DichThatCore

@MainActor
final class SelectionCaptureService {
    private let axCapture = AXSelectionCapture()
    private let clipboardCapture = ClipboardSelectionCapture()

    func capture(
        frontmostPID: pid_t?,
        mouseAnchor: CapturePoint
    ) async -> Result<SelectionCaptureOutput, SelectionCaptureError> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityPermissionMissing)
        }
        if let output = axCapture.capture(
            frontmostPID: frontmostPID,
            mouseAnchor: mouseAnchor
        ) {
            return .success(output)
        }
        return await clipboardCapture.capture(mouseAnchor: mouseAnchor)
    }
}
