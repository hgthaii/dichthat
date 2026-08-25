import Foundation

public struct TranslationMeaningGroup: Equatable, Sendable {
    public let partOfSpeech: String
    public let translations: [String]
    public let definition: String?
    public let example: String?
    public let synonyms: [String]

    public init(
        partOfSpeech: String,
        translations: [String],
        definition: String? = nil,
        example: String? = nil,
        synonyms: [String] = []
    ) {
        self.partOfSpeech = partOfSpeech
        self.translations = Array(translations.filter { !$0.isEmpty }.prefix(2))
        self.definition = definition?.nilIfEmpty
        self.example = example?.nilIfEmpty
        self.synonyms = Array(synonyms.filter { !$0.isEmpty }.prefix(5))
    }

    public func replacing(definition: String?, example: String?) -> TranslationMeaningGroup {
        TranslationMeaningGroup(
            partOfSpeech: partOfSpeech,
            translations: translations,
            definition: definition ?? self.definition,
            example: example ?? self.example,
            synonyms: synonyms
        )
    }

    public func replacing(synonyms: [String]) -> TranslationMeaningGroup {
        TranslationMeaningGroup(
            partOfSpeech: partOfSpeech,
            translations: translations,
            definition: definition,
            example: example,
            synonyms: synonyms
        )
    }
}

public struct TranslationEnrichment: Equatable, Sendable {
    public let phonetic: String?
    public let groups: [TranslationMeaningGroup]

    public init(phonetic: String? = nil, groups: [TranslationMeaningGroup]) {
        self.phonetic = phonetic?.nilIfEmpty
        self.groups = Array(groups.prefix(3))
    }

    public func merging(englishDictionary: EnglishDictionaryEnrichment?) -> TranslationEnrichment {
        guard let englishDictionary else { return self }
        var mergedGroups = groups
        for meaning in englishDictionary.meanings {
            guard let index = mergedGroups.firstIndex(where: {
                $0.partOfSpeech.caseInsensitiveCompare(meaning.partOfSpeech) == .orderedSame
            }) else { continue }
            let providerSynonyms = mergedGroups[index].synonyms
            var synonyms = providerSynonyms
            for value in meaning.synonyms where !synonyms.contains(where: {
                $0.caseInsensitiveCompare(value) == .orderedSame
            }) {
                synonyms.append(value)
            }
            mergedGroups[index] = mergedGroups[index].replacing(synonyms: synonyms)
        }
        return TranslationEnrichment(
            phonetic: englishDictionary.phoneticDisplay ?? phonetic,
            groups: mergedGroups
        )
    }
}

public enum TranslationMode: Equatable, Sendable {
    case compact
    case dictionary
}

public enum TranslationEnrichmentPolicy {
    public static let maximumWordScalars = 64
    public static let maximumRequests = 3
    public static let maximumBatchScalars = 5_000

    public static func mode(for route: LanguageRoute) -> TranslationMode {
        guard route.source == .english else { return .compact }
        let scalars = Array(route.text.unicodeScalars)
        guard !scalars.isEmpty, scalars.count <= maximumWordScalars else { return .compact }

        var previousWasSeparator = false
        for (index, scalar) in scalars.enumerated() {
            let value = scalar.value
            let isLetter = (65 ... 90).contains(value) || (97 ... 122).contains(value)
            let isSeparator = value == 39 || value == 45
            guard isLetter || isSeparator else { return .compact }
            if isSeparator {
                guard index > 0, index < scalars.count - 1, !previousWasSeparator else {
                    return .compact
                }
            }
            previousWasSeparator = isSeparator
        }
        return .dictionary
    }

    public static func requestCount(
        mode: TranslationMode,
        hasContextBatch: Bool
    ) -> Int {
        guard mode == .dictionary else { return 1 }
        return hasContextBatch ? maximumRequests : 2
    }
}

public struct TranslationContextSnippet: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case definition
        case example
    }

    public let id: String
    public let groupIndex: Int
    public let kind: Kind
    public let text: String

    public init(id: String, groupIndex: Int, kind: Kind, text: String) {
        self.id = id
        self.groupIndex = groupIndex
        self.kind = kind
        self.text = text
    }
}

public struct TranslationContextBatchEntry: Equatable, Sendable {
    public let snippet: TranslationContextSnippet
    public let startMarker: String
    public let endMarker: String
}

public struct TranslationContextBatch: Equatable, Sendable {
    public let text: String
    public let entries: [TranslationContextBatchEntry]
}

public enum TranslationMarkerNonce {
    public static let byteCount = 16

    public static func generate<Generator: RandomNumberGenerator>(
        using generator: inout Generator
    ) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(byteCount)
        while bytes.count < byteCount {
            var word = generator.next()
            for _ in 0 ..< MemoryLayout<UInt64>.size where bytes.count < byteCount {
                bytes.append(UInt8(truncatingIfNeeded: word))
                word >>= 8
            }
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

public enum TranslationContextBatchBuilder {
    public static func snippets(from enrichment: TranslationEnrichment) -> [TranslationContextSnippet] {
        var snippets: [TranslationContextSnippet] = []
        for (index, group) in enrichment.groups.enumerated() {
            if let definition = group.definition {
                snippets.append(TranslationContextSnippet(
                    id: "g\(index)d",
                    groupIndex: index,
                    kind: .definition,
                    text: definition
                ))
            }
            if let example = group.example {
                snippets.append(TranslationContextSnippet(
                    id: "g\(index)e",
                    groupIndex: index,
                    kind: .example,
                    text: example
                ))
            }
        }
        return snippets
    }

    public static func make(
        snippets: [TranslationContextSnippet],
        nonceCandidates: [String]
    ) -> TranslationContextBatch? {
        guard !snippets.isEmpty else { return nil }
        for nonce in nonceCandidates where isValidNonce(nonce) {
            if let batch = build(snippets: snippets, nonce: nonce) { return batch }
        }
        return nil
    }

    private static func build(
        snippets: [TranslationContextSnippet],
        nonce: String
    ) -> TranslationContextBatch? {
        var entries: [TranslationContextBatchEntry] = []
        var parts: [String] = []
        for (index, snippet) in snippets.enumerated() {
            let start = "__DICHTHAT_\(nonce)_\(index)_START__"
            let end = "__DICHTHAT_\(nonce)_\(index)_END__"
            guard !snippet.text.contains(start), !snippet.text.contains(end) else { return nil }
            let part = "\(start)\n\(snippet.text)\n\(end)"
            let candidate = (parts + [part]).joined(separator: "\n")
            guard candidate.unicodeScalars.count <= TranslationEnrichmentPolicy.maximumBatchScalars else {
                break
            }
            entries.append(TranslationContextBatchEntry(
                snippet: snippet,
                startMarker: start,
                endMarker: end
            ))
            parts.append(part)
        }
        guard !entries.isEmpty else { return nil }
        return TranslationContextBatch(text: parts.joined(separator: "\n"), entries: entries)
    }

    private static func isValidNonce(_ nonce: String) -> Bool {
        guard nonce.count == 32 else { return false }
        return nonce.unicodeScalars.allSatisfy {
            (48 ... 57).contains($0.value) || (65 ... 70).contains($0.value) || (97 ... 102).contains($0.value)
        }
    }
}

public enum TranslationContextBatchParser {
    public static func parse(
        translatedText: String,
        batch: TranslationContextBatch
    ) -> [String: String]? {
        var cursor = translatedText.startIndex
        var values: [String: String] = [:]
        for entry in batch.entries {
            guard translatedText.components(separatedBy: entry.startMarker).count == 2,
                  translatedText.components(separatedBy: entry.endMarker).count == 2,
                  let start = translatedText.range(
                    of: entry.startMarker,
                    range: cursor ..< translatedText.endIndex
                  ),
                  let end = translatedText.range(
                    of: entry.endMarker,
                    range: start.upperBound ..< translatedText.endIndex
                  )
            else { return nil }
            let value = String(translatedText[start.upperBound ..< end.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return nil }
            values[entry.snippet.id] = value
            cursor = end.upperBound
        }
        return values.count == batch.entries.count ? values : nil
    }

    public static func apply(
        localized: [String: String],
        batch: TranslationContextBatch,
        to enrichment: TranslationEnrichment
    ) -> TranslationEnrichment? {
        let snippets = TranslationContextBatchBuilder.snippets(from: enrichment)
        let expectedIDs = Set(batch.entries.map { $0.snippet.id })
        guard Set(localized.keys) == expectedIDs,
              expectedIDs.isSubset(of: Set(snippets.map(\.id)))
        else { return nil }
        var groups = enrichment.groups
        for snippet in snippets {
            guard expectedIDs.contains(snippet.id),
                  let value = localized[snippet.id],
                  groups.indices.contains(snippet.groupIndex)
            else {
                continue
            }
            let group = groups[snippet.groupIndex]
            switch snippet.kind {
            case .definition:
                groups[snippet.groupIndex] = group.replacing(definition: value, example: nil)
            case .example:
                groups[snippet.groupIndex] = group.replacing(definition: nil, example: value)
            }
        }
        return TranslationEnrichment(phonetic: enrichment.phonetic, groups: groups)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
