import DichThatCore
import NaturalLanguage

struct NaturalLanguageRouter: Sendable {
    func route(text: String) -> Result<LanguageRoute, TranslationFailure> {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageHints = [
            .english: 0.5,
            .vietnamese: 0.5,
        ]
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 8)
        let evidence = LanguageEvidence(
            dominantIdentifier: recognizer.dominantLanguage?.rawValue,
            englishConfidence: hypotheses[.english] ?? 0,
            vietnameseConfidence: hypotheses[.vietnamese] ?? 0
        )
        return LanguageRoutingPolicy.route(text: text, evidence: evidence)
    }
}
