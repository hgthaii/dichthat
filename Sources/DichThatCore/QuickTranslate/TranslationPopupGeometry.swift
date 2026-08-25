import Foundation

public enum TranslationPopupTailSide: Equatable, Sendable {
    case left
    case right
}

public struct TranslationPopupPlacement: Equatable, Sendable {
    public let origin: CapturePoint
    public let anchor: CapturePoint
    public let tailSide: TranslationPopupTailSide

    public init(origin: CapturePoint, anchor: CapturePoint, tailSide: TranslationPopupTailSide) {
        self.origin = origin
        self.anchor = anchor
        self.tailSide = tailSide
    }
}

public enum TranslationPopupGeometry {
    public static func placement(
        anchor: SelectionAnchor,
        mainDisplayHeight: Double,
        visibleFrame: CaptureBounds,
        popupWidth: Double,
        popupHeight: Double,
        tailInset: Double
    ) -> TranslationPopupPlacement {
        let endpoints = selectionEndpoints(anchor: anchor, mainDisplayHeight: mainDisplayHeight)
        let rightCandidate = endpoints.end
        let canFitRight = rightCandidate.x - tailInset + popupWidth <= visibleFrame.x + visibleFrame.width
        let tailSide: TranslationPopupTailSide = canFitRight ? .left : .right
        let selectedAnchor = canFitRight ? rightCandidate : endpoints.start
        let desiredX = tailSide == .left
            ? selectedAnchor.x - tailInset
            : selectedAnchor.x - popupWidth + tailInset
        let desiredY = selectedAnchor.y - popupHeight
        let x = clamp(desiredX, lower: visibleFrame.x, upper: visibleFrame.x + visibleFrame.width - popupWidth)
        let y = clamp(desiredY, lower: visibleFrame.y, upper: visibleFrame.y + visibleFrame.height - popupHeight)
        return TranslationPopupPlacement(
            origin: CapturePoint(x: x, y: y),
            anchor: selectedAnchor,
            tailSide: tailSide
        )
    }

    private static func selectionEndpoints(
        anchor: SelectionAnchor,
        mainDisplayHeight: Double
    ) -> (start: CapturePoint, end: CapturePoint) {
        switch anchor {
        case let .mouse(point):
            return (point, point)
        case let .bounds(bounds):
            let top = mainDisplayHeight - bounds.y
            let bottom = top - bounds.height
            return (
                CapturePoint(x: bounds.x, y: top),
                CapturePoint(x: bounds.x + bounds.width, y: bottom)
            )
        }
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), max(lower, upper))
    }
}
