public struct KeyboardShortcut: Codable, Equatable, Sendable {
    public struct Modifiers: OptionSet, Codable, Equatable, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)

        public static let supported: Modifiers = [.command, .option, .control, .shift]
        public static let activation: Modifiers = [.command, .option, .control]
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case unsupportedModifiers
        case requiresCommandControlOrOption
        case unusableKeyCode(UInt32)
    }

    public let keyCode: UInt32
    public let modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let defaultShortcut = KeyboardShortcut(
        keyCode: 17,
        modifiers: [.control, .option]
    )

    public func validate() throws(ValidationError) {
        guard modifiers.subtracting(.supported).isEmpty else {
            throw .unsupportedModifiers
        }
        guard !modifiers.intersection(.activation).isEmpty else {
            throw .requiresCommandControlOrOption
        }
        guard Self.keyDisplayNames[keyCode] != nil else {
            throw .unusableKeyCode(keyCode)
        }
    }

    public var displayText: String {
        let modifierText = [
            modifiers.contains(.control) ? "⌃" : "",
            modifiers.contains(.option) ? "⌥" : "",
            modifiers.contains(.shift) ? "⇧" : "",
            modifiers.contains(.command) ? "⌘" : "",
        ].joined()
        return modifierText + (Self.keyDisplayNames[keyCode] ?? "?")
    }

    private static let keyDisplayNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`", 51: "⌫", 53: "Esc", 96: "F5", 97: "F6", 98: "F7",
        99: "F3", 100: "F8", 101: "F9", 103: "F11", 109: "F10", 111: "F12",
        118: "F4", 120: "F2", 122: "F1", 123: "←", 124: "→", 125: "↓",
        126: "↑",
    ]
}
