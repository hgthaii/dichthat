import Foundation

public struct EnglishDictionaryMeaning: Equatable, Sendable {
    public let partOfSpeech: String
    public let synonyms: [String]

    public init(partOfSpeech: String, synonyms: [String]) {
        self.partOfSpeech = partOfSpeech
        self.synonyms = Array(synonyms.prefix(5))
    }
}

public struct EnglishDictionaryEnrichment: Equatable, Sendable {
    public let phonetics: [String]
    public let meanings: [EnglishDictionaryMeaning]

    public init(phonetics: [String], meanings: [EnglishDictionaryMeaning]) {
        self.phonetics = Array(phonetics.prefix(3))
        self.meanings = meanings
    }

    public var phoneticDisplay: String? {
        phonetics.isEmpty ? nil : phonetics.joined(separator: " · ")
    }
}

public enum EnglishDictionaryRequestBuilder {
    public static let timeout = CoreConfiguration.EnglishDictionary.timeout

    public static func request(word: String) -> URLRequest? {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty,
              let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { return nil }
        let url = CoreConfiguration.EnglishDictionary.endpoint.appendingPathComponent(encoded)
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.cachePolicy = .returnCacheDataElseLoad
        return request
    }
}

public enum EnglishDictionaryResponseParser {
    public static func parse(data: Data) -> EnglishDictionaryEnrichment? {
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return nil }
        var phonetics: [String] = []
        var synonymsByPartOfSpeech: [String: [String]] = [:]
        var partOfSpeechOrder: [String] = []

        for entry in entries {
            appendUnique(entry.phonetic, to: &phonetics)
            for phonetic in entry.phonetics ?? [] {
                appendUnique(phonetic.text, to: &phonetics)
            }
            for meaning in entry.meanings ?? [] {
                let partOfSpeech = meaning.partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !partOfSpeech.isEmpty else { continue }
                let key = partOfSpeech.lowercased()
                if synonymsByPartOfSpeech[key] == nil {
                    synonymsByPartOfSpeech[key] = []
                    partOfSpeechOrder.append(partOfSpeech)
                }
                for synonym in meaning.synonyms ?? [] {
                    appendUnique(synonym, to: &synonymsByPartOfSpeech[key, default: []])
                }
                for definition in meaning.definitions ?? [] {
                    for synonym in definition.synonyms ?? [] {
                        appendUnique(synonym, to: &synonymsByPartOfSpeech[key, default: []])
                    }
                }
            }
        }

        let meanings = partOfSpeechOrder.compactMap { partOfSpeech -> EnglishDictionaryMeaning? in
            let synonyms = synonymsByPartOfSpeech[partOfSpeech.lowercased()] ?? []
            guard !synonyms.isEmpty else { return nil }
            return EnglishDictionaryMeaning(partOfSpeech: partOfSpeech, synonyms: synonyms)
        }
        guard !phonetics.isEmpty || !meanings.isEmpty else { return nil }
        return EnglishDictionaryEnrichment(phonetics: phonetics, meanings: meanings)
    }

    private static func appendUnique(_ value: String?, to values: inout [String]) {
        guard let value else { return }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              !values.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame })
        else { return }
        values.append(normalized)
    }

    private struct Entry: Decodable {
        let phonetic: String?
        let phonetics: [Phonetic]?
        let meanings: [Meaning]?
    }

    private struct Phonetic: Decodable { let text: String? }

    private struct Meaning: Decodable {
        let partOfSpeech: String
        let synonyms: [String]?
        let definitions: [Definition]?
    }

    private struct Definition: Decodable { let synonyms: [String]? }
}
