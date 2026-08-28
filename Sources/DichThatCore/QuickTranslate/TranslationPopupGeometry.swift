import Foundation

public enum TranslationPopupTailSide: Equatable, Sendable {
    case left
    case right
}

public enum TranslationPopupTailEdge: Equatable, Sendable {
    case top
    case bottom
}

public enum TranslationPopupContext: Equatable, Sendable {
    case quickTranslate
    case menuBarInput
}

public struct TranslationPopupPlacement: Equatable, Sendable {
    public let origin: CapturePoint
    public let anchor: CapturePoint
    public let tailSide: TranslationPopupTailSide
    public let tailEdge: TranslationPopupTailEdge
    public let tailX: Double

    public init(
        origin: CapturePoint,
        anchor: CapturePoint,
        tailSide: TranslationPopupTailSide,
        tailEdge: TranslationPopupTailEdge,
        tailX: Double
    ) {
        self.origin = origin
        self.anchor = anchor
        self.tailSide = tailSide
        self.tailEdge = tailEdge
        self.tailX = tailX
    }
}

public enum TranslationPopupGeometry {
    public static func screenIndex(
        anchor: SelectionAnchor,
        mainDisplayHeight: Double,
        screenFrames: [CaptureBounds]
    ) -> Int? {
        guard !screenFrames.isEmpty else { return nil }
        switch anchor {
        case let .mouse(point):
            return closestScreenIndex(to: point, screenFrames: screenFrames)
        case let .bounds(bounds):
            let converted = CaptureBounds(
                x: bounds.x,
                y: mainDisplayHeight - bounds.y - bounds.height,
                width: bounds.width,
                height: bounds.height
            )
            let intersections = screenFrames.enumerated().map { index, frame in
                (index, intersectionArea(converted, frame))
            }
            if let best = intersections.max(by: { $0.1 < $1.1 }), best.1 > 0 {
                return best.0
            }
            return closestScreenIndex(
                to: CapturePoint(
                    x: converted.x + converted.width / 2,
                    y: converted.y + converted.height / 2
                ),
                screenFrames: screenFrames
            )
        }
    }

    public static func placement(
        anchor: SelectionAnchor,
        mainDisplayHeight: Double,
        visibleFrame: CaptureBounds,
        popupWidth: Double,
        popupHeight: Double,
        tailInset: Double,
        selectionClearance: Double,
        context: TranslationPopupContext,
        preferredTailEdge: TranslationPopupTailEdge? = nil
    ) -> TranslationPopupPlacement {
        let endpoints = selectionEndpoints(anchor: anchor, mainDisplayHeight: mainDisplayHeight)
        let verticalClearance = context == .quickTranslate ? selectionClearance : 0
        let rightCandidate = endpoints.lowerEnd
        let canFitRight = rightCandidate.x - tailInset + popupWidth <= visibleFrame.x + visibleFrame.width
        let tailSide: TranslationPopupTailSide = canFitRight ? .left : .right
        let lowerAnchor = canFitRight ? rightCandidate : endpoints.lowerStart
        let upperAnchor = canFitRight ? endpoints.upperEnd : endpoints.upperStart
        let canFitBelow = lowerAnchor.y - verticalClearance - popupHeight >= visibleFrame.y
        let tailEdge = preferredTailEdge ?? (canFitBelow ? .top : .bottom)
        let placeBelow = tailEdge == .top
        let selectedAnchor = placeBelow ? lowerAnchor : upperAnchor
        let desiredX = tailSide == .left
            ? selectedAnchor.x - tailInset
            : selectedAnchor.x - popupWidth + tailInset
        let desiredY = placeBelow
            ? selectedAnchor.y - popupHeight - verticalClearance
            : selectedAnchor.y + verticalClearance
        let x = clamp(desiredX, lower: visibleFrame.x, upper: visibleFrame.x + visibleFrame.width - popupWidth)
        let y = clamp(desiredY, lower: visibleFrame.y, upper: visibleFrame.y + visibleFrame.height - popupHeight)
        let tailX = clamp(
            selectedAnchor.x - x,
            lower: tailInset,
            upper: popupWidth - tailInset
        )
        return TranslationPopupPlacement(
            origin: CapturePoint(x: x, y: y),
            anchor: selectedAnchor,
            tailSide: tailSide,
            tailEdge: tailEdge,
            tailX: tailX
        )
    }

    public static func preferredTailEdge(
        anchor: SelectionAnchor,
        mainDisplayHeight: Double,
        visibleFrame: CaptureBounds,
        selectionClearance: Double,
        context: TranslationPopupContext
    ) -> TranslationPopupTailEdge {
        let endpoints = selectionEndpoints(anchor: anchor, mainDisplayHeight: mainDisplayHeight)
        let verticalClearance = context == .quickTranslate ? selectionClearance : 0
        let availableBelow = endpoints.lowerEnd.y - verticalClearance - visibleFrame.y
        let availableAbove = visibleFrame.y + visibleFrame.height
            - endpoints.upperEnd.y
            - verticalClearance
        return availableBelow >= availableAbove ? .top : .bottom
    }

    public static func maximumPopupHeight(
        anchor: SelectionAnchor,
        mainDisplayHeight: Double,
        visibleFrame: CaptureBounds,
        selectionClearance: Double,
        context: TranslationPopupContext,
        tailEdge: TranslationPopupTailEdge
    ) -> Double {
        let endpoints = selectionEndpoints(anchor: anchor, mainDisplayHeight: mainDisplayHeight)
        let verticalClearance = context == .quickTranslate ? selectionClearance : 0
        switch tailEdge {
        case .top:
            return max(0, endpoints.lowerEnd.y - verticalClearance - visibleFrame.y)
        case .bottom:
            return max(
                0,
                visibleFrame.y + visibleFrame.height
                    - endpoints.upperEnd.y
                    - verticalClearance
            )
        }
    }

    private static func selectionEndpoints(
        anchor: SelectionAnchor,
        mainDisplayHeight: Double
    ) -> (
        lowerStart: CapturePoint,
        lowerEnd: CapturePoint,
        upperStart: CapturePoint,
        upperEnd: CapturePoint
    ) {
        switch anchor {
        case let .mouse(point):
            return (point, point, point, point)
        case let .bounds(bounds):
            let top = mainDisplayHeight - bounds.y
            let bottom = top - bounds.height
            return (
                CapturePoint(x: bounds.x, y: bottom),
                CapturePoint(x: bounds.x + bounds.width, y: bottom),
                CapturePoint(x: bounds.x, y: top),
                CapturePoint(x: bounds.x + bounds.width, y: top)
            )
        }
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(max(value, lower), max(lower, upper))
    }

    private static func intersectionArea(_ lhs: CaptureBounds, _ rhs: CaptureBounds) -> Double {
        let width = max(0, min(lhs.x + lhs.width, rhs.x + rhs.width) - max(lhs.x, rhs.x))
        let height = max(0, min(lhs.y + lhs.height, rhs.y + rhs.height) - max(lhs.y, rhs.y))
        return width * height
    }

    private static func closestScreenIndex(
        to point: CapturePoint,
        screenFrames: [CaptureBounds]
    ) -> Int? {
        screenFrames.enumerated().min { lhs, rhs in
            squaredDistance(from: point, to: lhs.element)
                < squaredDistance(from: point, to: rhs.element)
        }?.offset
    }

    private static func squaredDistance(from point: CapturePoint, to bounds: CaptureBounds) -> Double {
        let nearestX = clamp(point.x, lower: bounds.x, upper: bounds.x + bounds.width)
        let nearestY = clamp(point.y, lower: bounds.y, upper: bounds.y + bounds.height)
        let dx = point.x - nearestX
        let dy = point.y - nearestY
        return dx * dx + dy * dy
    }
}
