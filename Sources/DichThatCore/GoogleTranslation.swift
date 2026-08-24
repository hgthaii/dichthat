import Foundation

public enum GoogleTranslationRequestBuilder {
    public static let endpoint = CoreConfiguration.GoogleTranslation.endpoint
    public static let timeout = CoreConfiguration.GoogleTranslation.timeout
    public static let maximumAttempts = CoreConfiguration.GoogleTranslation.maximumAttempts

    public static func request(
        for route: LanguageRoute,
        mode: TranslationMode = .compact
    ) -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: route.target.rawValue),
            URLQueryItem(name: "dt", value: "t"),
        ]
        if mode == .dictionary {
            queryItems.append(contentsOf: ["bd", "md", "rm", "ex"].map {
                URLQueryItem(name: "dt", value: $0)
            })
        }
        queryItems.append(URLQueryItem(name: "q", value: route.text))
        components.queryItems = queryItems
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return request
    }

    public static func contextRequest(batchText: String) -> URLRequest {
        var request = request(for: LanguageRoute(
            source: .english,
            target: .vietnamese,
            text: batchText
        ))
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        components.queryItems = components.queryItems?.map {
            $0.name == "sl" ? URLQueryItem(name: "sl", value: "en") : $0
        }
        request.url = components.url!
        return request
    }
}

public enum GoogleTranslationResponseParser {
    public static func parse(
        data: Data,
        expectedRoute: LanguageRoute
    ) -> Result<TranslationOutput, TranslationFailure> {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let rawSegments = root.first as? [Any]
        else {
            return .failure(.malformedResponse)
        }

        return primaryOutput(
            root: root,
            rawSegments: rawSegments,
            expectedRoute: expectedRoute,
            allowsMetadataRows: false,
            enrichment: nil
        )
    }

    public static func parseEnriched(
        data: Data,
        expectedRoute: LanguageRoute
    ) -> Result<TranslationOutput, TranslationFailure> {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let rawSegments = root.first as? [Any]
        else { return .failure(.malformedResponse) }

        let enrichment = parseOptionalEnrichment(root: root, segments: rawSegments)
        return primaryOutput(
            root: root,
            rawSegments: rawSegments,
            expectedRoute: expectedRoute,
            allowsMetadataRows: true,
            enrichment: enrichment
        )
    }

    private static func primaryOutput(
        root: [Any],
        rawSegments: [Any],
        expectedRoute: LanguageRoute,
        allowsMetadataRows: Bool,
        enrichment: TranslationEnrichment?
    ) -> Result<TranslationOutput, TranslationFailure> {
        guard !rawSegments.isEmpty else { return .failure(.emptyTranslation) }
        var translated = ""
        for rawSegment in rawSegments {
            guard let segment = rawSegment as? [Any], let first = segment.first else {
                return .failure(.malformedResponse)
            }
            if first is NSNull, allowsMetadataRows { continue }
            guard let value = first as? String else { return .failure(.malformedResponse) }
            translated += value
        }
        guard !translated.isEmpty else { return .failure(.emptyTranslation) }
        guard root.indices.contains(2), let sourceIdentifier = root[2] as? String else {
            return .failure(.malformedResponse)
        }
        guard let source = SupportedLanguage(rawValue: sourceIdentifier) else {
            return .failure(.unsupportedResponseLanguage(sourceIdentifier))
        }
        guard source == expectedRoute.source else {
            return .failure(.sourceLanguageMismatch(expected: expectedRoute.source, received: source))
        }
        return .success(TranslationOutput(
            sourceText: expectedRoute.text,
            text: translated,
            source: source,
            target: expectedRoute.target,
            enrichment: enrichment
        ))
    }

    private static func parseOptionalEnrichment(
        root: [Any],
        segments: [Any]
    ) -> TranslationEnrichment? {
        let phonetic = segments.compactMap { raw -> String? in
            guard let segment = raw as? [Any], segment.indices.contains(3) else { return nil }
            return nonemptyString(segment[3])
        }.first

        var groups: [TranslationMeaningGroup] = []
        if root.indices.contains(1), let dictionary = root[1] as? [Any] {
            for rawGroup in dictionary {
                guard groups.count < 3,
                      let group = rawGroup as? [Any],
                      group.indices.contains(1),
                      let partOfSpeech = nonemptyString(group[0]),
                      let rawTranslations = group[1] as? [Any]
                else { continue }
                let translations = rawTranslations.compactMap(nonemptyString)
                groups.append(TranslationMeaningGroup(
                    partOfSpeech: partOfSpeech,
                    translations: translations
                ))
            }
        }

        if root.indices.contains(12), let definitionGroups = root[12] as? [Any] {
            for rawGroup in definitionGroups {
                guard let group = rawGroup as? [Any],
                      group.indices.contains(1),
                      let partOfSpeech = nonemptyString(group[0]),
                      let definitions = group[1] as? [Any],
                      let firstDefinition = definitions.first as? [Any],
                      let definition = firstDefinition.first.flatMap(nonemptyString)
                else { continue }
                if let index = groups.firstIndex(where: {
                    $0.partOfSpeech.caseInsensitiveCompare(partOfSpeech) == .orderedSame
                }) {
                    groups[index] = groups[index].replacing(definition: definition, example: nil)
                } else if groups.count < 3 {
                    groups.append(TranslationMeaningGroup(
                        partOfSpeech: partOfSpeech,
                        translations: [],
                        definition: definition
                    ))
                }
            }
        }

        if root.indices.contains(13), let exampleGroups = root[13] as? [Any] {
            for (index, rawExamples) in exampleGroups.prefix(groups.count).enumerated() {
                guard let examples = rawExamples as? [Any],
                      let firstExample = examples.first as? [Any],
                      let rawExample = firstExample.first.flatMap(nonemptyString),
                      let example = sanitizedGoogleBoldText(rawExample)
                else { continue }
                groups[index] = groups[index].replacing(definition: nil, example: example)
            }
        }

        guard phonetic != nil || !groups.isEmpty else { return nil }
        return TranslationEnrichment(phonetic: phonetic, groups: groups)
    }

    private static func sanitizedGoogleBoldText(_ value: String) -> String? {
        let withoutOpenTag = value.replacingOccurrences(
            of: "<b>", with: "", options: [.caseInsensitive]
        )
        let withoutKnownMarkup = withoutOpenTag.replacingOccurrences(
            of: "</b>", with: "", options: [.caseInsensitive]
        )
        return nonemptyString(withoutKnownMarkup)
    }

    private static func nonemptyString(_ value: Any) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum GoogleTranslationTransportPolicy {
    public static func failure(forHTTPStatus statusCode: Int) -> TranslationFailure? {
        (200 ... 299).contains(statusCode) ? nil : .httpStatus(statusCode)
    }

    public static func failure(for code: URLError.Code) -> TranslationFailure {
        switch code {
        case .cancelled: return .cancelled
        case .timedOut: return .timedOut
        default: return .networkUnavailable
        }
    }
}
