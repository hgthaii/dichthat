import Foundation

public struct LanguageEvidence: Equatable, Sendable {
    public let dominantIdentifier: String?
    public let englishConfidence: Double
    public let vietnameseConfidence: Double

    public init(
        dominantIdentifier: String?,
        englishConfidence: Double,
        vietnameseConfidence: Double
    ) {
        self.dominantIdentifier = dominantIdentifier
        self.englishConfidence = englishConfidence
        self.vietnameseConfidence = vietnameseConfidence
    }
}

public enum LanguageRoutingPolicy {
    public static let maximumUnicodeScalars = CoreConfiguration.LanguageRouting.maximumUnicodeScalars
    public static let minimumConfidence = CoreConfiguration.LanguageRouting.minimumConfidence
    public static let minimumConfidenceMargin = CoreConfiguration.LanguageRouting.minimumConfidenceMargin
    public static let rescueConfidence = CoreConfiguration.LanguageRouting.rescueConfidence
    public static let rescueConfidenceMargin = CoreConfiguration.LanguageRouting.rescueConfidenceMargin

    public static func route(
        text: String,
        evidence: LanguageEvidence
    ) -> Result<LanguageRoute, TranslationFailure> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyInput) }
        guard trimmed.unicodeScalars.count <= maximumUnicodeScalars else {
            return .failure(.inputTooLong(maximumUnicodeScalars: maximumUnicodeScalars))
        }

        let english = evidence.englishConfidence
        let vietnamese = evidence.vietnameseConfidence
        guard english.isFinite, vietnamese.isFinite,
              english >= 0, vietnamese >= 0,
              english > 0 || vietnamese > 0
        else {
            return .failure(.ambiguousLanguage)
        }

        if let dominantIdentifier = evidence.dominantIdentifier,
           let dominant = SupportedLanguage(rawValue: dominantIdentifier) {
            let dominantConfidence = dominant == .english ? english : vietnamese
            let alternativeConfidence = dominant == .english ? vietnamese : english
            guard dominantConfidence >= minimumConfidence,
                  dominantConfidence - alternativeConfidence >= minimumConfidenceMargin
            else { return .failure(.ambiguousLanguage) }
            return .success(LanguageRoute(
                source: dominant,
                target: dominant.opposite,
                text: trimmed
            ))
        }

        guard english != vietnamese else { return .failure(.ambiguousLanguage) }
        let rescue: SupportedLanguage = english > vietnamese ? .english : .vietnamese
        let rescueValue = max(english, vietnamese)
        let alternativeValue = min(english, vietnamese)
        guard rescueValue >= rescueConfidence,
              rescueValue - alternativeValue >= rescueConfidenceMargin
        else {
            return .failure(evidence.dominantIdentifier == nil
                ? .ambiguousLanguage
                : .unsupportedLanguage)
        }
        return .success(LanguageRoute(source: rescue, target: rescue.opposite, text: trimmed))
    }
}
