import Testing
@testable import DichThatCore

@Test("Normal modifier release preserves a valid candidate")
func modifierReleasePreservesCandidate() {
    var state = ShortcutRecorderState()
    #expect(state.modifiersChanged(to: [.control]) == .recording([.control]))
    #expect(state.modifiersChanged(to: [.control, .option]) == .recording([.control, .option]))
    #expect(state.keyDown(
        keyCode: 17,
        modifierFlags: [.control, .option]
    ) == .valid(.defaultShortcut))

    #expect(state.modifiersChanged(to: [.control]) == .valid(.defaultShortcut))
    #expect(state.modifiersChanged(to: []) == .valid(.defaultShortcut))
    #expect(state.candidate == .defaultShortcut)
    #expect(state.canUseCandidate)
}

@Test("Shift-only invalid result survives modifier release")
func shiftOnlyInvalidSurvivesRelease() {
    var state = ShortcutRecorderState()
    _ = state.modifiersChanged(to: [.shift])
    #expect(state.keyDown(
        keyCode: 17,
        modifierFlags: [.shift]
    ) == .invalid(.requiresCommandControlOrOption))

    #expect(state.modifiersChanged(to: []) == .invalid(.requiresCommandControlOrOption))
    #expect(state.phase == .invalid(.requiresCommandControlOrOption))
    #expect(state.candidate == nil)
    #expect(!state.canUseCandidate)
}

@Test("Unusable-key error survives release until a new attempt")
func unusableKeyErrorSurvivesRelease() {
    var state = ShortcutRecorderState()
    _ = state.modifiersChanged(to: [.control])
    #expect(state.keyDown(
        keyCode: 999,
        modifierFlags: [.control]
    ) == .invalid(.unusableKeyCode(999)))

    #expect(state.modifiersChanged(to: []) == .invalid(.unusableKeyCode(999)))
    #expect(!state.canUseCandidate)
    #expect(state.modifiersChanged(to: [.option]) == .recording([.option]))
    #expect(state.phase == .recording([.option]))
}

@Test("Empty-modifier invalid result clears on the next modifier down")
func emptyModifierInvalidStartsCleanAttempt() {
    var state = ShortcutRecorderState()
    #expect(state.keyDown(
        keyCode: 17,
        modifierFlags: []
    ) == .invalid(.requiresCommandControlOrOption))
    #expect(state.phase == .invalid(.requiresCommandControlOrOption))
    #expect(!state.canUseCandidate)

    #expect(state.modifiersChanged(to: [.control]) == .recording([.control]))
    #expect(state.phase == .recording([.control]))
    #expect(state.candidate == nil)
    #expect(!state.canUseCandidate)
}

@Test("New modifier down after release starts a new attempt")
func newModifierDownStartsNewAttempt() {
    var state = ShortcutRecorderState()
    _ = state.modifiersChanged(to: [.control, .option])
    _ = state.keyDown(keyCode: 17, modifierFlags: [.control, .option])
    _ = state.modifiersChanged(to: [])

    #expect(state.modifiersChanged(to: [.command]) == .recording([.command]))
    #expect(state.candidate == nil)
    #expect(!state.canUseCandidate)
}

@Test("Reset clears candidate and modifier lifecycle")
func resetClearsRecorderState() {
    var state = ShortcutRecorderState()
    _ = state.keyDown(keyCode: 17, modifierFlags: [.control, .option])

    state.reset()

    #expect(state.candidate == nil)
    #expect(state.modifierFlags.isEmpty)
    #expect(state.phase == .idle)
    #expect(!state.canUseCandidate)
    #expect(state.modifiersChanged(to: [.option]) == .recording([.option]))
}
