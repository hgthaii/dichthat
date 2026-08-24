import Testing
@testable import DichThatCore

private func englishRoute(_ text: String) -> LanguageRoute {
    LanguageRoute(source: .english, target: .vietnamese, text: text)
}

private struct FixedRandomNumberGenerator: RandomNumberGenerator {
    var values: [UInt64]
    var callCount = 0

    mutating func next() -> UInt64 {
        defer { callCount += 1 }
        return values[callCount]
    }
}

@Test("Marker nonce uses exactly 16 random bytes and 32 hex characters")
func markerNonceHasFullRandomWidth() {
    var generator = FixedRandomNumberGenerator(values: [
        0x0706_0504_0302_0100,
        0x0f0e_0d0c_0b0a_0908,
    ])
    let nonce = TranslationMarkerNonce.generate(using: &generator)
    #expect(TranslationMarkerNonce.byteCount == 16)
    #expect(generator.callCount == 2)
    #expect(nonce == "000102030405060708090a0b0c0d0e0f")
    #expect(nonce.count == 32)
    #expect(nonce.unicodeScalars.allSatisfy {
        (48 ... 57).contains($0.value) || (97 ... 102).contains($0.value)
    })
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
            example: "example"
        )
    }
    let enrichment = TranslationEnrichment(groups: groups)
    #expect(enrichment.groups.map(\.partOfSpeech) == ["pos0", "pos1", "pos2"])
    #expect(enrichment.groups.allSatisfy { $0.translations == ["a", "b"] })
}

@Test("Batch regenerates colliding nonce and preserves ordered identifiers")
func markerCollisionRegeneration() throws {
    let first = String(repeating: "a", count: 32)
    let second = String(repeating: "b", count: 32)
    let collision = "__DICHTHAT_\(first)_0_START__"
    let snippets = [TranslationContextSnippet(
        id: "g0d", groupIndex: 0, kind: .definition, text: "text \(collision)"
    )]
    let batch = try #require(TranslationContextBatchBuilder.make(
        snippets: snippets,
        nonceCandidates: [first, second]
    ))
    #expect(batch.entries[0].startMarker.contains(second))
    #expect(batch.text.unicodeScalars.count <= 5_000)
}

@Test("Batch includes only complete entries within scalar cap")
func batchScalarLimit() throws {
    let nonce = String(repeating: "c", count: 32)
    let snippets = [
        TranslationContextSnippet(id: "g0d", groupIndex: 0, kind: .definition, text: "short"),
        TranslationContextSnippet(
            id: "g0e", groupIndex: 0, kind: .example,
            text: String(repeating: "x", count: 5_000)
        ),
    ]
    let batch = try #require(TranslationContextBatchBuilder.make(
        snippets: snippets,
        nonceCandidates: [nonce]
    ))
    #expect(batch.entries.map { $0.snippet.id } == ["g0d"])
    #expect(batch.text.unicodeScalars.count <= 5_000)
}

@Test("Marker parser requires exact once and ordered round trip")
func strictMarkerRoundTrip() throws {
    let nonce = String(repeating: "d", count: 32)
    let snippets = [
        TranslationContextSnippet(id: "g0d", groupIndex: 0, kind: .definition, text: "one"),
        TranslationContextSnippet(id: "g0e", groupIndex: 0, kind: .example, text: "two"),
    ]
    let batch = try #require(TranslationContextBatchBuilder.make(
        snippets: snippets,
        nonceCandidates: [nonce]
    ))
    let first = batch.entries[0]
    let second = batch.entries[1]
    let valid = "\(first.startMarker) một \(first.endMarker)\n\(second.startMarker) hai \(second.endMarker)"
    #expect(TranslationContextBatchParser.parse(translatedText: valid, batch: batch)
        == ["g0d": "một", "g0e": "hai"])
    #expect(TranslationContextBatchParser.parse(
        translatedText: valid + first.startMarker, batch: batch
    ) == nil)
    let reordered = "\(second.startMarker) hai \(second.endMarker)\n\(first.startMarker) một \(first.endMarker)"
    #expect(TranslationContextBatchParser.parse(translatedText: reordered, batch: batch) == nil)
    #expect(TranslationContextBatchParser.parse(
        translatedText: "\(first.startMarker) một \(first.endMarker)", batch: batch
    ) == nil)
}

@Test("Localized context applies all selected entries or none")
func localizedContextMerge() throws {
    let enrichment = TranslationEnrichment(groups: [TranslationMeaningGroup(
        partOfSpeech: "noun",
        translations: ["nghĩa"],
        definition: "definition",
        example: "example"
    )])
    let batch = try #require(TranslationContextBatchBuilder.make(
        snippets: TranslationContextBatchBuilder.snippets(from: enrichment),
        nonceCandidates: [String(repeating: "e", count: 32)]
    ))
    #expect(TranslationContextBatchParser.apply(
        localized: ["g0d": "định nghĩa"], batch: batch, to: enrichment
    ) == nil)
    let merged = try #require(TranslationContextBatchParser.apply(
        localized: ["g0d": "định nghĩa", "g0e": "ví dụ"],
        batch: batch,
        to: enrichment
    ))
    #expect(merged.groups[0].definition == "định nghĩa")
    #expect(merged.groups[0].example == "ví dụ")
    #expect(TranslationEnrichmentPolicy.maximumRequests == 2)
    #expect(TranslationEnrichmentPolicy.requestCount(mode: .dictionary, hasContextBatch: true) == 2)
    #expect(TranslationEnrichmentPolicy.requestCount(mode: .dictionary, hasContextBatch: false) == 1)
    #expect(TranslationEnrichmentPolicy.requestCount(mode: .compact, hasContextBatch: true) == 1)
}
