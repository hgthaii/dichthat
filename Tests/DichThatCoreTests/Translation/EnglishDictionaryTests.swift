import Foundation
import Testing
@testable import DichThatCore

@Test("Dictionary request normalizes and safely encodes an English word")
func englishDictionaryRequest() throws {
    let request = try #require(EnglishDictionaryRequestBuilder.request(word: " Lead "))
    #expect(request.url?.absoluteString == "https://api.dictionaryapi.dev/api/v2/entries/en/lead")
    #expect(request.timeoutInterval == 5)
}

@Test("Dictionary parser keeps distinct IPA variants and English synonyms by context")
func englishDictionaryParser() throws {
    let data = Data("""
    [
      {
        "phonetic": "/lɛd/",
        "phonetics": [{"text":"/lɛd/"}],
        "meanings": [{
          "partOfSpeech":"noun",
          "synonyms":["clue", "hint"],
          "definitions":[{"synonyms":["tip", "clue"]}]
        }]
      },
      {
        "phonetic":"/liːd/",
        "phonetics":[],
        "meanings":[{
          "partOfSpeech":"verb",
          "synonyms":["guide", "direct"],
          "definitions":[]
        }]
      }
    ]
    """.utf8)
    let parsed = try #require(EnglishDictionaryResponseParser.parse(data: data))
    #expect(parsed.phonetics == ["/lɛd/", "/liːd/"])
    #expect(parsed.phoneticDisplay == "/lɛd/ · /liːd/")
    #expect(parsed.meanings == [
        EnglishDictionaryMeaning(partOfSpeech: "noun", synonyms: ["clue", "hint", "tip"]),
        EnglishDictionaryMeaning(partOfSpeech: "verb", synonyms: ["guide", "direct"]),
    ])
}

@Test("Dictionary IPA and synonyms merge without replacing translated context")
func englishDictionaryMerge() {
    let original = TranslationEnrichment(
        phonetic: "old",
        groups: [TranslationMeaningGroup(
            partOfSpeech: "verb",
            translations: ["chỉ huy"],
            definition: "điều khiển hoặc hướng dẫn",
            synonyms: ["head"]
        )]
    )
    let dictionary = EnglishDictionaryEnrichment(
        phonetics: ["/liːd/"],
        meanings: [EnglishDictionaryMeaning(
            partOfSpeech: "verb",
            synonyms: ["guide", "direct", "head"]
        )]
    )
    let merged = original.merging(englishDictionary: dictionary)
    #expect(merged.phonetic == "/liːd/")
    #expect(merged.groups[0].definition == "điều khiển hoặc hướng dẫn")
    #expect(merged.groups[0].synonyms == ["head", "guide", "direct"])
}
