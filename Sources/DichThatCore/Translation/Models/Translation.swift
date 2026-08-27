import Foundation

public enum SupportedLanguage: String, Codable, CaseIterable, Equatable, Sendable {
    case english = "en"
    case vietnamese = "vi"

    public var opposite: SupportedLanguage {
        switch self {
        case .english: return .vietnamese
        case .vietnamese: return .english
        }
    }

    public var displayName: String {
        switch self {
        case .english:
            return AppLanguage.current.localized(english: "English", vietnamese: "Tiếng Anh")
        case .vietnamese:
            return AppLanguage.current.localized(english: "Vietnamese", vietnamese: "Tiếng Việt")
        }
    }
}

public struct LanguageRoute: Equatable, Sendable {
    public let source: SupportedLanguage
    public let target: SupportedLanguage
    public let text: String

    public init(source: SupportedLanguage, target: SupportedLanguage, text: String) {
        self.source = source
        self.target = target
        self.text = text
    }
}

public struct TranslationOutput: Equatable, Sendable {
    public let sourceText: String
    public let text: String
    public let source: SupportedLanguage
    public let target: SupportedLanguage
    public let enrichment: TranslationEnrichment?

    public init(
        sourceText: String,
        text: String,
        source: SupportedLanguage,
        target: SupportedLanguage,
        enrichment: TranslationEnrichment? = nil
    ) {
        self.sourceText = sourceText
        self.text = text
        self.source = source
        self.target = target
        self.enrichment = enrichment
    }
}

public struct TranslationSpeechContent: Equatable, Sendable {
    public let text: String
    public let language: SupportedLanguage

    public init(text: String, language: SupportedLanguage) {
        self.text = text
        self.language = language
    }
}

public enum TranslationFailure: Error, Equatable, Sendable {
    case emptyInput
    case inputTooLong(maximumUnicodeScalars: Int)
    case unsupportedLanguage
    case ambiguousLanguage
    case cancelled
    case timedOut
    case networkUnavailable
    case httpStatus(Int)
    case malformedResponse
    case emptyTranslation
    case unsupportedResponseLanguage(String)
    case sourceLanguageMismatch(expected: SupportedLanguage, received: SupportedLanguage)
}
