public enum ShortcutCapture {
    public struct ModifierFlags: OptionSet, Equatable, Sendable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let command = ModifierFlags(rawValue: 1 << 0)
        public static let option = ModifierFlags(rawValue: 1 << 1)
        public static let control = ModifierFlags(rawValue: 1 << 2)
        public static let shift = ModifierFlags(rawValue: 1 << 3)
    }

    public enum CaptureResult: Equatable, Sendable {
        case modifierOnly
        case valid(KeyboardShortcut)
        case invalid(KeyboardShortcut.ValidationError)
    }

    public static func makeCandidate(
        keyCode: UInt32?,
        modifierFlags: ModifierFlags
    ) -> CaptureResult {
        guard let keyCode else { return .modifierOnly }

        var modifiers: KeyboardShortcut.Modifiers = []
        if modifierFlags.contains(.command) { modifiers.insert(.command) }
        if modifierFlags.contains(.option) { modifiers.insert(.option) }
        if modifierFlags.contains(.control) { modifiers.insert(.control) }
        if modifierFlags.contains(.shift) { modifiers.insert(.shift) }

        let shortcut = KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
        do {
            try shortcut.validate()
            return .valid(shortcut)
        } catch let error {
            return .invalid(error)
        }
    }
}
