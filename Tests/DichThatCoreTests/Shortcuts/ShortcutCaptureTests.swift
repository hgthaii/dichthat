import Testing
@testable import DichThatCore

@Test("Capture maps event flags to a valid semantic shortcut")
func captureMapsFlagsToShortcut() {
    let result = ShortcutCapture.makeCandidate(
        keyCode: 6,
        modifierFlags: [.option, .shift]
    )
    #expect(result == .valid(.defaultShortcut))
}

@Test("Capture reports modifier-only and invalid events")
func captureRejectsIncompleteEvents() {
    #expect(ShortcutCapture.makeCandidate(
        keyCode: nil,
        modifierFlags: [.control]
    ) == .modifierOnly)
    #expect(ShortcutCapture.makeCandidate(
        keyCode: 17,
        modifierFlags: [.shift]
    ) == .invalid(.requiresCommandControlOrOption))
    #expect(ShortcutCapture.makeCandidate(
        keyCode: 999,
        modifierFlags: [.control]
    ) == .invalid(.unusableKeyCode(999)))
}
