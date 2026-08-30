import Testing
@testable import DichThatCore

private func englishRoute(_ text: String) -> LanguageRoute {
    LanguageRoute(source: .english, target: .vietnamese, text: text)
}

@Test("Dictionary qualifier enforces ASCII lexical grammar")
func dictionaryQualifierGrammar() {
    #expect(TranslationEnrichmentPolicy.mode(for: englishRoute("word")) == .dictionary)
    #expect(TranslationEnrichmentPolicy.mode(for: englishRoute("don't")) == .dictionary)
    #expect(TranslationEnrichmentPolicy.mode(for: englishRoute("state-of-the-art")) == .dictionary)
    for value in ["two words", "two\nwords", "word2", "café", "-word", "word-", "word--word"] {
        #expect(TranslationEnrichmentPolicy.mode(for: englishRoute(value)) == .compact)
    }
    #expect(TranslationEnrichmentPolicy.mode(for: LanguageRoute(
        source: .vietnamese, target: .english, text: "xin"
    )) == .compact)
}

@Test("Dictionary qualifier accepts 64 scalars and rejects 65")
func dictionaryQualifierLength() {
    #expect(TranslationEnrichmentPolicy.mode(
        for: englishRoute(String(repeating: "a", count: 64))
    ) == .dictionary)
    #expect(TranslationEnrichmentPolicy.mode(
        for: englishRoute(String(repeating: "a", count: 65))
    ) == .compact)
}

@Test("Enrichment limits groups and translations in provider order")
func enrichmentLimits() {
    let groups = (0 ..< 5).map { index in
        TranslationMeaningGroup(
            partOfSpeech: "pos\(index)",
            translations: ["a", "b", "c"],
            definition: "definition",
            example: "example",
            synonyms: ["one", "two", "three", "four", "five", "six"]
        )
    }
    let enrichment = TranslationEnrichment(groups: groups)
    #expect(enrichment.groups.map(\.partOfSpeech) == ["pos0", "pos1", "pos2"])
    #expect(enrichment.groups.allSatisfy { $0.translations == ["a", "b"] })
    #expect(enrichment.groups.allSatisfy { $0.synonyms == ["one", "two", "three", "four", "five"] })
}

@Test("Context snippets preserve group and field order")
func contextSnippetOrder() {
    let enrichment = TranslationEnrichment(groups: [
        TranslationMeaningGroup(
            partOfSpeech: "noun",
            translations: [],
            definition: "first definition",
            example: "first example"
        ),
        TranslationMeaningGroup(
            partOfSpeech: "verb",
            translations: [],
            definition: "second definition"
        ),
    ])

    let snippets = TranslationContextSnippetBuilder.snippets(from: enrichment)
    #expect(snippets.map(\.groupIndex) == [0, 0, 1])
    #expect(snippets.map(\.kind) == [.definition, .example, .definition])
    #expect(snippets.map(\.text) == ["first definition", "first example", "second definition"])
}
