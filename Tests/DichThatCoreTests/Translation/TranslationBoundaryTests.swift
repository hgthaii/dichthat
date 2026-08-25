import Testing
@testable import DichThatCore

private let clearEnglish = LanguageEvidence(
    dominantIdentifier: "en",
    englishConfidence: 0.99,
    vietnameseConfidence: 0
)

@Test("Exactly 5000 Unicode scalars are accepted and 5001 rejected")
func exactScalarBoundary() {
    let accepted = String(repeating: "a", count: 5_000)
    let rejected = String(repeating: "a", count: 5_001)
    #expect(LanguageRoutingPolicy.route(text: accepted, evidence: clearEnglish).isSuccess)
    #expect(LanguageRoutingPolicy.route(text: rejected, evidence: clearEnglish)
        == .failure(.inputTooLong(maximumUnicodeScalars: 5_000)))
}

@Test("Boundary counts combining and emoji scalars rather than graphemes")
func scalarCountDiffersFromStringCount() {
    let combiningGrapheme = "e\u{301}"
    let combining = String(repeating: combiningGrapheme, count: 2_501)
    #expect(combining.count == 2_501)
    #expect(combining.unicodeScalars.count == 5_002)
    #expect(LanguageRoutingPolicy.route(text: combining, evidence: clearEnglish)
        == .failure(.inputTooLong(maximumUnicodeScalars: 5_000)))

    let familyEmoji = "👨‍👩‍👧‍👦"
    let emojiText = String(repeating: familyEmoji, count: 1_000)
    #expect(emojiText.count == 1_000)
    #expect(emojiText.unicodeScalars.count > 5_000)
    #expect(LanguageRoutingPolicy.route(text: emojiText, evidence: clearEnglish)
        == .failure(.inputTooLong(maximumUnicodeScalars: 5_000)))
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
