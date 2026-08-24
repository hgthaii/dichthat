import DichThatCore
import Foundation

struct TranslationEngine: Sendable {
    private let router = NaturalLanguageRouter()
    private let provider = GoogleWebTranslationProvider()

    func translate(text: String) async -> Result<TranslationOutput, TranslationFailure> {
        if Task.isCancelled { return .failure(.cancelled) }
        let route: LanguageRoute
        switch router.route(text: text) {
        case let .success(value):
            route = value
        case let .failure(error):
            return .failure(error)
        }
        if Task.isCancelled { return .failure(.cancelled) }
        let mode = TranslationEnrichmentPolicy.mode(for: route)
        let primaryResult = await provider.translate(route: route, mode: mode)
        guard case let .success(primary) = primaryResult else { return primaryResult }
        if Task.isCancelled { return .failure(.cancelled) }
        guard mode == .dictionary, let enrichment = primary.enrichment else {
            return .success(primary)
        }

        let snippets = TranslationContextBatchBuilder.snippets(from: enrichment)
        var nonceGenerator = SystemRandomNumberGenerator()
        var nonceCandidates: [String] = []
        nonceCandidates.reserveCapacity(3)
        for _ in 0 ..< 3 {
            nonceCandidates.append(TranslationMarkerNonce.generate(using: &nonceGenerator))
        }
        guard let batch = TranslationContextBatchBuilder.make(
            snippets: snippets,
            nonceCandidates: nonceCandidates
        ) else { return .success(primary) }

        let localizedResult = await provider.localize(batch: batch)
        if Task.isCancelled { return .failure(.cancelled) }
        guard case let .success(localized) = localizedResult,
              let localizedEnrichment = TranslationContextBatchParser.apply(
                localized: localized,
                batch: batch,
                to: enrichment
              )
        else {
            return .success(primary)
        }
        return .success(TranslationOutput(
            sourceText: primary.sourceText,
            text: primary.text,
            source: primary.source,
            target: primary.target,
            enrichment: localizedEnrichment
        ))
    }
}
