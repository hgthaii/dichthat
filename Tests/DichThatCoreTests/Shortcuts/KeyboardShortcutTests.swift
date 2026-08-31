import Testing
@testable import DichThatCore

@Test("Quick Translate defaults to Shift-Option-Z")
func defaultShortcutIsShiftOptionZ() throws {
    let shortcut = KeyboardShortcut.defaultShortcut
    try shortcut.validate()
    #expect(shortcut.keyCode == 6)
    #expect(shortcut.modifiers == [.option, .shift])
    #expect(shortcut.displayText == "⌥⇧Z")
}

@Test("Translation input defaults to Control-Option-Shift-Z")
func defaultInputShortcutIsControlOptionShiftZ() throws {
    let shortcut = KeyboardShortcut.defaultInputShortcut
    try shortcut.validate()
    #expect(shortcut.keyCode == 6)
    #expect(shortcut.modifiers == [.control, .option, .shift])
    #expect(shortcut.displayText == "⌃⌥⇧Z")
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

@Test("Shortcut editor accepts only a single A-Z or 0-9 key")
func shortcutEditorAlphanumericMapping() {
    #expect(KeyboardShortcut.keyCode(forAlphanumeric: "a") == 0)
    #expect(KeyboardShortcut.keyCode(forAlphanumeric: "T") == 17)
    #expect(KeyboardShortcut.keyCode(forAlphanumeric: "0") == 29)
    #expect(KeyboardShortcut.keyCode(forAlphanumeric: "9") == 25)
    #expect(KeyboardShortcut.keyCode(forAlphanumeric: "AB") == nil)
    #expect(KeyboardShortcut.keyCode(forAlphanumeric: "-") == nil)
    #expect(KeyboardShortcut(keyCode: 17, modifiers: [.control]).alphanumericKey == "T")
}
