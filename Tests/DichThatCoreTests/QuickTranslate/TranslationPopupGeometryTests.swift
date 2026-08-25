import Testing
@testable import DichThatCore

private let visible = CaptureBounds(x: 0, y: 0, width: 1000, height: 800)

@Test("Popup uses selection end and left tail when there is room")
func popupUsesSelectionEnd() {
    let placement = TranslationPopupGeometry.placement(
        anchor: .bounds(CaptureBounds(x: 100, y: 100, width: 120, height: 20)),
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 200,
        tailInset: 26
    )
    #expect(placement.anchor == CapturePoint(x: 220, y: 780))
    #expect(placement.tailSide == .left)
    #expect(placement.origin == CapturePoint(x: 194, y: 580))
}

@Test("Popup switches to selection start and right tail near right screen edge")
func popupUsesSelectionStartNearRightEdge() {
    let placement = TranslationPopupGeometry.placement(
        anchor: .bounds(CaptureBounds(x: 850, y: 100, width: 100, height: 20)),
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 200,
        tailInset: 26
    )
    #expect(placement.anchor == CapturePoint(x: 850, y: 800))
    #expect(placement.tailSide == .right)
    #expect(placement.origin == CapturePoint(x: 496, y: 600))
}

@Test("Mouse fallback is clamped to visible screen")
func popupClampsMouseFallback() {
    let placement = TranslationPopupGeometry.placement(
        anchor: .mouse(CapturePoint(x: 5, y: 50)),
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 200,
        tailInset: 26
    )
    #expect(placement.origin == CapturePoint(x: 0, y: 0))
}
