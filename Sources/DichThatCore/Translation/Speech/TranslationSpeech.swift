public enum TranslationSpeechTarget: Equatable, Sendable {
    case source
    case translation
}

public extension SupportedLanguage {
    var speechVoiceCode: String {
        switch self {
        case .english: return "en-US"
        case .vietnamese: return "vi-VN"
        }
    }
}

public struct TranslationSpeechState: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case stop
        case speak(TranslationSpeechContent)
        case unavailable(SupportedLanguage)
    }

    public private(set) var activeTarget: TranslationSpeechTarget?

    public init() {}

    public mutating func request(
        target: TranslationSpeechTarget,
        content: TranslationSpeechContent,
        voiceAvailable: Bool
    ) -> [Action] {
        var actions: [Action] = []
        if activeTarget != nil { actions.append(.stop) }
        guard voiceAvailable else {
            activeTarget = nil
            actions.append(.unavailable(content.language))
            return actions
        }
        activeTarget = target
        actions.append(.speak(content))
        return actions
    }

    public mutating func stop() -> [Action] {
        guard activeTarget != nil else { return [] }
        activeTarget = nil
        return [.stop]
    }
}
