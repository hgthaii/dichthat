import Testing
@testable import DichThatCore

private let visible = CaptureBounds(x: 0, y: 0, width: 1000, height: 800)

@Test("Selected text chooses its secondary display instead of the main display")
func selectedTextChoosesSecondaryDisplay() {
    let screens = [
        CaptureBounds(x: 0, y: 0, width: 1440, height: 900),
        CaptureBounds(x: 1440, y: 0, width: 1920, height: 1080),
    ]
    let index = TranslationPopupGeometry.screenIndex(
        anchor: .bounds(CaptureBounds(x: 1700, y: 240, width: 180, height: 24)),
        mainDisplayHeight: 900,
        screenFrames: screens
    )
    #expect(index == 1)
}

@Test("Selected text above the main display chooses the upper display")
func selectedTextChoosesUpperDisplay() {
    let screens = [
        CaptureBounds(x: 0, y: 0, width: 1440, height: 900),
        CaptureBounds(x: 100, y: 900, width: 1200, height: 800),
    ]
    let index = TranslationPopupGeometry.screenIndex(
        anchor: .bounds(CaptureBounds(x: 400, y: -420, width: 180, height: 24)),
        mainDisplayHeight: 900,
        screenFrames: screens
    )
    #expect(index == 1)
}

@Test("A selection crossing displays chooses the display containing most of it")
func spanningSelectionChoosesLargestIntersection() {
    let screens = [
        CaptureBounds(x: 0, y: 0, width: 1440, height: 900),
        CaptureBounds(x: 1440, y: 0, width: 1920, height: 1080),
    ]
    let index = TranslationPopupGeometry.screenIndex(
        anchor: .bounds(CaptureBounds(x: 1400, y: 300, width: 240, height: 24)),
        mainDisplayHeight: 900,
        screenFrames: screens
    )
    #expect(index == 1)
}

@Test("Popup uses selection end and left tail when there is room")
func popupUsesSelectionEnd() {
    let placement = TranslationPopupGeometry.placement(
        anchor: .bounds(CaptureBounds(x: 100, y: 100, width: 120, height: 20)),
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 200,
        tailInset: 26,
        selectionClearance: 8,
        context: .quickTranslate
    )
    #expect(placement.anchor == CapturePoint(x: 220, y: 780))
    #expect(placement.tailSide == .left)
    #expect(placement.tailEdge == .top)
    #expect(placement.tailX == 26)
    #expect(placement.origin == CapturePoint(x: 194, y: 572))
}

@Test("Popup switches to selection start and right tail near right screen edge")
func popupUsesSelectionStartNearRightEdge() {
    let placement = TranslationPopupGeometry.placement(
        anchor: .bounds(CaptureBounds(x: 850, y: 100, width: 100, height: 20)),
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 200,
        tailInset: 26,
        selectionClearance: 8,
        context: .quickTranslate
    )
    #expect(placement.anchor == CapturePoint(x: 850, y: 780))
    #expect(placement.tailSide == .right)
    #expect(placement.tailEdge == .top)
    #expect(placement.tailX == 354)
    #expect(placement.origin == CapturePoint(x: 496, y: 572))
}

@Test("Mouse fallback is clamped to visible screen")
func popupClampsMouseFallback() {
    let placement = TranslationPopupGeometry.placement(
        anchor: .mouse(CapturePoint(x: 5, y: 50)),
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 200,
        tailInset: 26,
        selectionClearance: 8,
        context: .menuBarInput
    )
    #expect(placement.tailX == 26)
    #expect(placement.tailEdge == .bottom)
    #expect(placement.origin == CapturePoint(x: 0, y: 50))
}

@Test("Quick Translate mouse fallback keeps selection clearance")
func quickTranslateMouseFallbackKeepsClearance() {
    let placement = TranslationPopupGeometry.placement(
        anchor: .mouse(CapturePoint(x: 500, y: 600)),
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 200,
        tailInset: 26,
        selectionClearance: 8,
        context: .quickTranslate
    )
    #expect(placement.origin.y == 392)
    #expect(placement.origin.y + 200 + 8 == placement.anchor.y)
}

@Test("Menu bar input stays attached to its status item anchor")
func menuBarInputHasNoSelectionClearance() {
    let placement = TranslationPopupGeometry.placement(
        anchor: .mouse(CapturePoint(x: 500, y: 600)),
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 200,
        tailInset: 26,
        selectionClearance: 8,
        context: .menuBarInput
    )
    #expect(placement.origin.y == 400)
    #expect(placement.origin.y + 200 == placement.anchor.y)
}

@Test("Quick Translate flips above the selection when it cannot fit below")
func quickTranslateFlipsAboveSelection() {
    let placement = TranslationPopupGeometry.placement(
        anchor: .bounds(CaptureBounds(x: 100, y: 850, width: 120, height: 20)),
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 200,
        tailInset: 26,
        selectionClearance: 8,
        context: .quickTranslate
    )
    #expect(placement.anchor == CapturePoint(x: 220, y: 50))
    #expect(placement.tailEdge == .bottom)
    #expect(placement.origin == CapturePoint(x: 194, y: 58))
}

@Test("Quick Translate chooses the side with more room before content arrives")
func quickTranslateChoosesRoomierSide() {
    let anchor = SelectionAnchor.bounds(
        CaptureBounds(x: 100, y: 610, width: 120, height: 20)
    )
    let edge = TranslationPopupGeometry.preferredTailEdge(
        anchor: anchor,
        mainDisplayHeight: 900,
        visibleFrame: visible,
        selectionClearance: 8,
        context: .quickTranslate
    )
    #expect(edge == .bottom)
    #expect(TranslationPopupGeometry.maximumPopupHeight(
        anchor: anchor,
        mainDisplayHeight: 900,
        visibleFrame: visible,
        selectionClearance: 8,
        context: .quickTranslate,
        tailEdge: edge
    ) == 502)
}

@Test("A preferred side remains stable when the popup grows")
func preferredSideRemainsStable() {
    let anchor = SelectionAnchor.bounds(
        CaptureBounds(x: 100, y: 610, width: 120, height: 20)
    )
    let loading = TranslationPopupGeometry.placement(
        anchor: anchor,
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 120,
        tailInset: 26,
        selectionClearance: 8,
        context: .quickTranslate,
        preferredTailEdge: .bottom
    )
    let result = TranslationPopupGeometry.placement(
        anchor: anchor,
        mainDisplayHeight: 900,
        visibleFrame: visible,
        popupWidth: 380,
        popupHeight: 500,
        tailInset: 26,
        selectionClearance: 8,
        context: .quickTranslate,
        preferredTailEdge: .bottom
    )
    #expect(loading.tailEdge == .bottom)
    #expect(result.tailEdge == .bottom)
    #expect(loading.origin.y == result.origin.y)
}
