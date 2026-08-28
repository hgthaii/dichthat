import DichThatCore
import Foundation

struct TranslationEngine: Sendable {
    private let router = NaturalLanguageRouter()
    private let provider: AppleTranslationProvider
    private let dictionaryProvider = OfflineDictionaryProvider()

    init(provider: AppleTranslationProvider) {
        self.provider = provider
    }

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
        async let dictionaryLookup: EnglishDictionaryEnrichment? = lookupDictionary(
            route: route,
            mode: mode
        )
        let primaryResult = await provider.translate(route: route)
        guard case let .success(primary) = primaryResult else { return primaryResult }
        if Task.isCancelled { return .failure(.cancelled) }
        let dictionary = await dictionaryLookup
        if Task.isCancelled { return .failure(.cancelled) }
        guard mode == .dictionary, let dictionary else {
            return .success(primary)
        }
        let englishEnrichment = TranslationEnrichment(
            phonetic: dictionary.phoneticDisplay,
            pronunciations: dictionary.pronunciations,
            groups: dictionary.meanings.map { meaning in
                TranslationMeaningGroup(
                    partOfSpeech: meaning.partOfSpeech,
                    translations: [],
                    definition: meaning.definition,
                    example: meaning.example,
                    synonyms: meaning.synonyms
                )
            }
        )
        let enrichment = await localized(enrichment: englishEnrichment)
        if Task.isCancelled { return .failure(.cancelled) }
        return .success(TranslationOutput(
            sourceText: primary.sourceText,
            text: primary.text,
            source: primary.source,
            target: primary.target,
            enrichment: enrichment
        ))
    }

    private func lookupDictionary(
        route: LanguageRoute,
        mode: TranslationMode
    ) async -> EnglishDictionaryEnrichment? {
        guard mode == .dictionary, route.source == .english else { return nil }
        return dictionaryProvider.lookup(word: route.text)
    }

    private func localized(enrichment: TranslationEnrichment) async -> TranslationEnrichment {
        let snippets = TranslationContextBatchBuilder.snippets(from: enrichment)
        guard !snippets.isEmpty else { return enrichment }
        let texts = snippets.map(\.text)
        guard case let .success(values) = await provider.translate(
            texts: texts,
            source: .english,
            target: .vietnamese
        ), values.count == snippets.count else { return enrichment }

        var groups = enrichment.groups
        for (snippet, value) in zip(snippets, values) where groups.indices.contains(snippet.groupIndex) {
            let group = groups[snippet.groupIndex]
            switch snippet.kind {
            case .definition:
                groups[snippet.groupIndex] = group.replacing(definition: value, example: nil)
            case .example:
                groups[snippet.groupIndex] = group.replacing(definition: nil, example: value)
            }
        }
        return TranslationEnrichment(
            phonetic: enrichment.phonetic,
            pronunciations: enrichment.pronunciations,
            groups: groups
        )
    }
}
