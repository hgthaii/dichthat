import ApplicationServices
import DichThatCore

final class AXSelectionObservation {
    func observe(context: SelectionTriggerContext) -> SelectionObservationResult {
        guard AXIsProcessTrusted() else { return .unavailable }

        let output = AXSelectionCapture().capture(
            frontmostPID: context.targetPID,
            mouseAnchor: context.mouseAnchor
        )
        guard let output else {
            return .heuristicMouse
        }
        switch output.anchor {
        case let .bounds(bounds):
            return .validBounds(bounds)
        case .mouse:
            return .heuristicMouse
        }
    }
}
