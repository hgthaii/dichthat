import Foundation
import Testing
@testable import DichThatCore

private let englishRoute = LanguageRoute(
    source: .english,
    target: .vietnamese,
    text: "Hello & welcome?"
)

@Test("Google request uses exact endpoint and parameters")
func googleRequestParameters() throws {
    let request = GoogleTranslationRequestBuilder.request(for: englishRoute)
    let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
    #expect(components.scheme == "https")
    #expect(components.host == "translate.googleapis.com")
    #expect(components.path == "/translate_a/single")
    let query = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value) })
    #expect(query["client"] == "gtx")
    #expect(query["sl"] == "auto")
    #expect(query["tl"] == "vi")
    #expect(query["dt"] == "t")
    #expect(query["q"] == "Hello & welcome?")
    #expect(request.timeoutInterval == 5)
    #expect(GoogleTranslationRequestBuilder.maximumAttempts == 1)
}

@Test("Dictionary request repeats exact enrichment query flags")
func dictionaryRequestParameters() throws {
    let request = GoogleTranslationRequestBuilder.request(for: englishRoute, mode: .dictionary)
    let components = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
    let values = components.queryItems!.filter { $0.name == "dt" }.compactMap(\.value)
    #expect(values == ["t", "bd", "md", "rm", "ex"])
    #expect(components.queryItems!.first(where: { $0.name == "q" })?.value == englishRoute.text)

    let context = GoogleTranslationRequestBuilder.contextRequest(batchText: "marked")
    let contextItems = try #require(URLComponents(url: context.url!, resolvingAgainstBaseURL: false)).queryItems!
    #expect(contextItems.filter { $0.name == "dt" }.compactMap(\.value) == ["t"])
    #expect(contextItems.first(where: { $0.name == "sl" })?.value == "en")
    #expect(contextItems.first(where: { $0.name == "tl" })?.value == "vi")
}

@Test("Parser handles one, multiple and additive response fields")
func parserHandlesSegmentsAndAdditiveFields() throws {
    let one = Data("[[[\"Xin chào\",\"Hello\",null,null]],null,\"en\"]".utf8)
    #expect(GoogleTranslationResponseParser.parse(data: one, expectedRoute: englishRoute)
        == .success(TranslationOutput(
            sourceText: englishRoute.text,
            text: "Xin chào", source: .english, target: .vietnamese
        )))

    let multiple = Data("[[[\"Xin \",\"Hello \",null,null],[\"chào\",\"there\",null,null]],null,\"en\",null,{\"future\":true}]".utf8)
    #expect(GoogleTranslationResponseParser.parse(data: multiple, expectedRoute: englishRoute)
        == .success(TranslationOutput(
            sourceText: englishRoute.text,
            text: "Xin chào", source: .english, target: .vietnamese
        )))
}

@Test("Enriched parser extracts bounded optional schema and phonetic")
func enrichedParser() throws {
    let root: [Any] = [
        [
            ["ngữ cảnh", englishRoute.text, NSNull(), NSNull(), 10],
            [NSNull(), NSNull(), NSNull(), "ˈkäntekst"],
        ],
        [
            ["noun", ["bối cảnh", "văn cảnh", "hoàn cảnh"], [], englishRoute.text, 1],
            ["verb", ["đặt vào bối cảnh"], [], englishRoute.text, 1],
        ],
        "en", NSNull(), NSNull(), NSNull(), 1, [], [], NSNull(), NSNull(), NSNull(),
        [
            ["noun", [["the circumstances around an event", NSNull(), NSNull()]], englishRoute.text, 1],
        ],
        [
            [["words gain meaning from their context", NSNull(), NSNull(), NSNull(), NSNull(), englishRoute.text]],
        ],
    ]
    let data = try JSONSerialization.data(withJSONObject: root)
    let output = try #require(GoogleTranslationResponseParser.parseEnriched(
        data: data,
        expectedRoute: englishRoute
    ).success)
    #expect(output.text == "ngữ cảnh")
    #expect(output.enrichment?.phonetic == "ˈkäntekst")
    #expect(output.enrichment?.groups.count == 2)
    #expect(output.enrichment?.groups[0].translations == ["bối cảnh", "văn cảnh"])
    #expect(output.enrichment?.groups[0].definition == "the circumstances around an event")
    #expect(output.enrichment?.groups[0].example == "words gain meaning from their context")
}

@Test("Enriched examples remove only known Google bold tags without losing surrounding text")
func enrichedExampleBoldMarkupIsSanitized() throws {
    let example = "Use <b>shortcut</b> keys before <B>saving</B>; keep 1 < 2 and <i>italics</i>."
    let root: [Any] = [
        [["lối tắt", englishRoute.text, NSNull(), NSNull(), 10]],
        [["noun", ["lối tắt"], [], englishRoute.text, 1]],
        "en", NSNull(), NSNull(), NSNull(), 1, [], [], NSNull(), NSNull(), NSNull(),
        [["noun", [["a shorter route", NSNull(), NSNull()]], englishRoute.text, 1]],
        [[[example, NSNull(), NSNull(), NSNull(), NSNull(), englishRoute.text]]],
    ]
    let data = try JSONSerialization.data(withJSONObject: root)
    let output = try #require(GoogleTranslationResponseParser.parseEnriched(
        data: data,
        expectedRoute: englishRoute
    ).success)
    #expect(output.enrichment?.groups[0].example
        == "Use shortcut keys before saving; keep 1 < 2 and <i>italics</i>.")
}

@Test("Malformed optional enrichment preserves valid primary translation")
func malformedOptionalEnrichmentIsIgnored() throws {
    let root: [Any] = [
        [["ngữ cảnh", englishRoute.text, NSNull(), NSNull(), 10]],
        [42, [NSNull()]],
        "en",
    ]
    let data = try JSONSerialization.data(withJSONObject: root)
    let output = try #require(GoogleTranslationResponseParser.parseEnriched(
        data: data,
        expectedRoute: englishRoute
    ).success)
    #expect(output.text == "ngữ cảnh")
    #expect(output.enrichment == nil)
}

@Test("Parser rejects malformed, empty and missing segments")
func parserRejectsInvalidSegments() {
    #expect(GoogleTranslationResponseParser.parse(
        data: Data("not json".utf8), expectedRoute: englishRoute
    ) == .failure(.malformedResponse))
    #expect(GoogleTranslationResponseParser.parse(
        data: Data("[[],null,\"en\"]".utf8), expectedRoute: englishRoute
    ) == .failure(.emptyTranslation))
    #expect(GoogleTranslationResponseParser.parse(
        data: Data("[[[42]],null,\"en\"]".utf8), expectedRoute: englishRoute
    ) == .failure(.malformedResponse))
}

private extension Result {
    var success: Success? {
        guard case let .success(value) = self else { return nil }
        return value
    }
}

@Test("Transport errors map to typed cancellation timeout and network failures")
func transportErrorMapping() {
    #expect(GoogleTranslationTransportPolicy.failure(forHTTPStatus: 200) == nil)
    #expect(GoogleTranslationTransportPolicy.failure(forHTTPStatus: 429) == .httpStatus(429))
    #expect(GoogleTranslationTransportPolicy.failure(for: .cancelled) == .cancelled)
    #expect(GoogleTranslationTransportPolicy.failure(for: .timedOut) == .timedOut)
    #expect(GoogleTranslationTransportPolicy.failure(for: .notConnectedToInternet) == .networkUnavailable)
}

@Test("Parser requires supported source agreeing with local route")
func parserValidatesSource() {
    let mismatch = Data("[[[\"Hello\",\"Xin chào\"]],null,\"vi\"]".utf8)
    #expect(GoogleTranslationResponseParser.parse(data: mismatch, expectedRoute: englishRoute)
        == .failure(.sourceLanguageMismatch(expected: .english, received: .vietnamese)))
    #expect(GoogleTranslationResponseParser.parseEnriched(data: mismatch, expectedRoute: englishRoute)
        == .failure(.sourceLanguageMismatch(expected: .english, received: .vietnamese)))
    let unsupported = Data("[[[\"Bonjour\",\"Hello\"]],null,\"fr\"]".utf8)
    #expect(GoogleTranslationResponseParser.parse(data: unsupported, expectedRoute: englishRoute)
        == .failure(.unsupportedResponseLanguage("fr")))
    let missing = Data("[[[\"Xin chào\",\"Hello\"]]]".utf8)
    #expect(GoogleTranslationResponseParser.parse(data: missing, expectedRoute: englishRoute)
        == .failure(.malformedResponse))
}
