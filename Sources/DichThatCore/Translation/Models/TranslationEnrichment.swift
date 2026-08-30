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
}

public struct TranslationEnrichment: Equatable, Sendable {
    public let phonetic: String?
    public let pronunciations: [EnglishPronunciation]
    public let groups: [TranslationMeaningGroup]

    public init(
        phonetic: String? = nil,
        pronunciations: [EnglishPronunciation] = [],
        groups: [TranslationMeaningGroup]
    ) {
        self.phonetic = phonetic?.nilIfEmpty
        self.pronunciations = Array(pronunciations.prefix(3))
        self.groups = Array(groups.prefix(3))
    }

    public var displayPronunciations: [EnglishPronunciation] {
        if !pronunciations.isEmpty { return pronunciations }
        guard let phonetic else { return [] }
        return [EnglishPronunciation(phonetic: phonetic)]
    }
}

public enum TranslationMode: Equatable, Sendable {
    case compact
    case dictionary
}

public enum TranslationEnrichmentPolicy {
    public static let maximumWordScalars = 64

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
}

public struct TranslationContextSnippet: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case definition
        case example
    }

    public let groupIndex: Int
    public let kind: Kind
    public let text: String

    public init(groupIndex: Int, kind: Kind, text: String) {
        self.groupIndex = groupIndex
        self.kind = kind
        self.text = text
    }
}

public enum TranslationContextSnippetBuilder {
    public static func snippets(from enrichment: TranslationEnrichment) -> [TranslationContextSnippet] {
        var snippets: [TranslationContextSnippet] = []
        for (index, group) in enrichment.groups.enumerated() {
            if let definition = group.definition {
                snippets.append(TranslationContextSnippet(
                    groupIndex: index,
                    kind: .definition,
                    text: definition
                ))
            }
            if let example = group.example {
                snippets.append(TranslationContextSnippet(
                    groupIndex: index,
                    kind: .example,
                    text: example
                ))
            }
        }
        return snippets
    }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
