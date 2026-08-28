import Foundation

public struct EnglishPronunciation: Equatable, Sendable {
    public let phonetic: String

    public init(phonetic: String) {
        self.phonetic = phonetic
    }
}

public struct EnglishDictionaryMeaning: Equatable, Sendable {
    public let partOfSpeech: String
    public let definition: String
    public let example: String?
    public let synonyms: [String]

    public init(
        partOfSpeech: String,
        definition: String,
        example: String? = nil,
        synonyms: [String]
    ) {
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.example = example
        self.synonyms = Array(synonyms.prefix(5))
    }
}

public struct EnglishDictionaryEnrichment: Equatable, Sendable {
    public let phonetics: [String]
    public let pronunciations: [EnglishPronunciation]
    public let meanings: [EnglishDictionaryMeaning]

    public init(
        phonetics: [String],
        pronunciations: [EnglishPronunciation] = [],
        meanings: [EnglishDictionaryMeaning]
    ) {
        self.phonetics = Array(phonetics.prefix(3))
        self.pronunciations = Array(pronunciations.prefix(3))
        self.meanings = Array(meanings.prefix(3))
    }

    public var phoneticDisplay: String? {
        phonetics.isEmpty ? nil : phonetics.joined(separator: " · ")
    }
}
