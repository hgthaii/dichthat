public struct ShortcutRecorderState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case idle
        case recording(ShortcutCapture.ModifierFlags)
        case valid(KeyboardShortcut)
        case invalid(KeyboardShortcut.ValidationError)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var modifierFlags: ShortcutCapture.ModifierFlags = []
    private var releasedAllModifiersAfterResult = false

    public init() {}

    public var candidate: KeyboardShortcut? {
        guard case let .valid(shortcut) = phase else { return nil }
        return shortcut
    }

    public var canUseCandidate: Bool {
        if case .valid = phase { return true }
        return false
    }

    public mutating func modifiersChanged(
        to newFlags: ShortcutCapture.ModifierFlags
    ) -> Phase {
        let previousFlags = modifierFlags
        modifierFlags = newFlags

        switch phase {
        case .valid, .invalid:
            if newFlags.isEmpty {
                releasedAllModifiersAfterResult = true
                return phase
            }
            if releasedAllModifiersAfterResult && previousFlags.isEmpty {
                phase = .recording(newFlags)
                releasedAllModifiersAfterResult = false
            }
            return phase
        case .idle, .recording:
            phase = .recording(newFlags)
            return phase
        }
    }

    public mutating func keyDown(
        keyCode: UInt32,
        modifierFlags: ShortcutCapture.ModifierFlags
    ) -> ShortcutCapture.CaptureResult {
        self.modifierFlags = modifierFlags
        releasedAllModifiersAfterResult = modifierFlags.isEmpty

        let result = ShortcutCapture.makeCandidate(
            keyCode: keyCode,
            modifierFlags: modifierFlags
        )
        switch result {
        case let .valid(shortcut):
            phase = .valid(shortcut)
        case let .invalid(error):
            phase = .invalid(error)
        case .modifierOnly:
            phase = .recording(modifierFlags)
        }
        return result
    }

    public mutating func reset() {
        phase = .idle
        modifierFlags = []
        releasedAllModifiersAfterResult = false
    }
}
