import Testing
@testable import DichThatCore

@Test("Default shortcut is Control-Option-T")
func defaultShortcutIsControlOptionT() throws {
    let shortcut = KeyboardShortcut.defaultShortcut
    try shortcut.validate()
    #expect(shortcut.keyCode == 17)
    #expect(shortcut.modifiers == [.control, .option])
    #expect(shortcut.displayText == "⌃⌥T")
}

@Test("Shortcut validation rejects unsafe combinations")
func shortcutValidationRejectsUnsafeCombinations() {
    #expect(throws: KeyboardShortcut.ValidationError.requiresCommandControlOrOption) {
        try KeyboardShortcut(keyCode: 17, modifiers: []).validate()
    }
    #expect(throws: KeyboardShortcut.ValidationError.requiresCommandControlOrOption) {
        try KeyboardShortcut(keyCode: 17, modifiers: [.shift]).validate()
    }
    #expect(throws: KeyboardShortcut.ValidationError.unusableKeyCode(999)) {
        try KeyboardShortcut(keyCode: 999, modifiers: [.control]).validate()
    }
    #expect(throws: KeyboardShortcut.ValidationError.unsupportedModifiers) {
        try KeyboardShortcut(
            keyCode: 17,
            modifiers: .init(rawValue: 1 << 7)
        ).validate()
    }
}

@Test("Shortcut display ordering is deterministic")
func shortcutDisplayOrderingIsDeterministic() {
    let shortcut = KeyboardShortcut(
        keyCode: 0,
        modifiers: [.command, .shift, .option, .control]
    )
    #expect(shortcut.displayText == "⌃⌥⇧⌘A")
}
