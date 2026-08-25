import Testing
@testable import DichThatCore

@Test("Shortcut keeps targeting the source app after popup receives focus")
func selectionTargetFallsBackFromOwnApp() {
    #expect(SelectionTargetResolver.targetPID(
        frontmostPID: 20,
        ownPID: 20,
        lastExternalPID: 10
    ) == 10)
    #expect(SelectionTargetResolver.targetPID(
        frontmostPID: 30,
        ownPID: 20,
        lastExternalPID: 10
    ) == 30)
    #expect(SelectionTargetResolver.targetPID(
        frontmostPID: 20,
        ownPID: 20,
        lastExternalPID: nil
    ) == nil)
}
