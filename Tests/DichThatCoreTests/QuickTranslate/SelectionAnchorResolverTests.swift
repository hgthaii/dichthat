import Testing
@testable import DichThatCore

@Test("Observed selection anchor replaces only cursor fallback")
func selectionAnchorResolution() {
    let cursor = SelectionAnchor.mouse(CapturePoint(x: 900, y: 700))
    let bounds = SelectionAnchor.bounds(CaptureBounds(x: 100, y: 120, width: 80, height: 20))
    #expect(SelectionAnchorResolver.resolve(captured: cursor, observed: bounds) == bounds)
    #expect(SelectionAnchorResolver.resolve(captured: bounds, observed: cursor) == bounds)
    #expect(SelectionAnchorResolver.resolve(captured: cursor, observed: nil) == cursor)
}
