import Testing
@testable import DichThatCore

@Test("English routes to Vietnamese")
func englishRoutesToVietnamese() {
    let result = LanguageRoutingPolicy.route(
        text: "  A clearly written English sentence.  ",
        evidence: LanguageEvidence(
            dominantIdentifier: "en",
            englishConfidence: 0.94,
            vietnameseConfidence: 0.02
        )
    )
    #expect(result == .success(LanguageRoute(
        source: .english,
        target: .vietnamese,
        text: "A clearly written English sentence."
    )))
}

@Test("Vietnamese routes to English")
func vietnameseRoutesToEnglish() {
    let result = LanguageRoutingPolicy.route(
        text: "Đây là một câu tiếng Việt rõ ràng.",
        evidence: LanguageEvidence(
            dominantIdentifier: "vi",
            englishConfidence: 0.01,
            vietnameseConfidence: 0.97
        )
    )
    #expect(result == .success(LanguageRoute(
        source: .vietnamese,
        target: .english,
        text: "Đây là một câu tiếng Việt rõ ràng."
    )))
}

@Test("Unsupported dominant language does not override strong English evidence")
func unsupportedDominantRoutesEnglishEvidence() {
    let result = LanguageRoutingPolicy.route(
        text: "Bonjour tout le monde",
        evidence: LanguageEvidence(
            dominantIdentifier: "fr",
            englishConfidence: 0.9,
            vietnameseConfidence: 0.01
        )
    )
    #expect(result == .success(LanguageRoute(
        source: .english,
        target: .vietnamese,
        text: "Bonjour tout le monde"
    )))
}

@Test("Unsupported dominant language does not override strong Vietnamese evidence")
func unsupportedDominantRoutesVietnameseEvidence() {
    let result = LanguageRoutingPolicy.route(
        text: "chào bạn",
        evidence: LanguageEvidence(
            dominantIdentifier: "fr",
            englishConfidence: 0.02,
            vietnameseConfidence: 0.95
        )
    )
    #expect(result == .success(LanguageRoute(
        source: .vietnamese,
        target: .english,
        text: "chào bạn"
    )))
}

@Test("Unsupported dominant with moderate constrained evidence is rejected")
func unsupportedDominantModerateEvidenceRejected() {
    let result = LanguageRoutingPolicy.route(
        text: "Bonjour tout le monde",
        evidence: LanguageEvidence(
            dominantIdentifier: "fr",
            englishConfidence: 0.825,
            vietnameseConfidence: 0.175
        )
    )
    #expect(result == .failure(.unsupportedLanguage))
}

@Test("Ordinary short English passes supported-dominant thresholds")
func ordinaryShortEnglishAccepted() {
    let result = LanguageRoutingPolicy.route(
        text: "hello",
        evidence: LanguageEvidence(
            dominantIdentifier: "en",
            englishConfidence: 0.831,
            vietnameseConfidence: 0.169
        )
    )
    #expect(result == .success(LanguageRoute(
        source: .english,
        target: .vietnamese,
        text: "hello"
    )))
}

@Test("No English or Vietnamese evidence and exact ties are ambiguous")
func absentOrTiedEvidenceRejected() {
    let absent = LanguageRoutingPolicy.route(
        text: "short",
        evidence: LanguageEvidence(
            dominantIdentifier: nil,
            englishConfidence: 0,
            vietnameseConfidence: 0
        )
    )
    #expect(absent == .failure(.ambiguousLanguage))
    let tied = LanguageRoutingPolicy.route(
        text: "mixed",
        evidence: LanguageEvidence(
            dominantIdentifier: "fr",
            englishConfidence: 0.5,
            vietnameseConfidence: 0.5
        )
    )
    #expect(tied == .failure(.ambiguousLanguage))
}
