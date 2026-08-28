import Testing
@testable import DichThatCore

@Test("Offline dictionary models keep compact US pronunciation and lexical context")
func offlineDictionaryModels() {
    let meaning = EnglishDictionaryMeaning(
        partOfSpeech: "verb",
        definition: "direct the course of something",
        example: "She leads the team.",
        synonyms: ["guide", "direct", "head"]
    )
    let dictionary = EnglishDictionaryEnrichment(
        phonetics: ["/liːd/", "/lɛd/"],
        pronunciations: [
            EnglishPronunciation(phonetic: "/liːd/"),
            EnglishPronunciation(phonetic: "/lɛd/"),
        ],
        meanings: [meaning]
    )
    #expect(dictionary.phoneticDisplay == "/liːd/ · /lɛd/")
    #expect(dictionary.pronunciations.count == 2)
    #expect(dictionary.meanings == [meaning])
}

@Test("Generic IPA defaults to the US pronunciation")
func offlineDictionaryPronunciationFallback() {
    let enrichment = TranslationEnrichment(phonetic: "/praɪvət/", groups: [])
    #expect(enrichment.displayPronunciations == [
        EnglishPronunciation(phonetic: "/praɪvət/"),
    ])
}
