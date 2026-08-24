import XCTest
@testable import DichThatCore

final class CoreConfigurationTests: XCTestCase {
    func testNumericProductTunablesRemainFrozen() {
        let integerCases: [(String, Int, Int)] = [
            ("maximum Unicode scalars", CoreConfiguration.LanguageRouting.maximumUnicodeScalars, 5_000),
            ("maximum Google attempts", CoreConfiguration.GoogleTranslation.maximumAttempts, 1),
        ]
        for (name, actual, expected) in integerCases {
            XCTAssertEqual(actual, expected, name)
        }

        let floatingPointCases: [(String, Double, Double)] = [
            ("minimum confidence", CoreConfiguration.LanguageRouting.minimumConfidence, 0.55),
            ("minimum confidence margin", CoreConfiguration.LanguageRouting.minimumConfidenceMargin, 0.15),
            ("rescue confidence", CoreConfiguration.LanguageRouting.rescueConfidence, 0.90),
            ("rescue confidence margin", CoreConfiguration.LanguageRouting.rescueConfidenceMargin, 0.80),
            ("Google timeout", CoreConfiguration.GoogleTranslation.timeout, 5),
            ("minimum drag distance", CoreConfiguration.SelectionObservation.minimumDragDistance, 4),
        ]
        for (name, actual, expected) in floatingPointCases {
            XCTAssertEqual(actual, expected, accuracy: 0.000_001, name)
        }
    }

    func testStringProductConfigurationRemainsFrozen() {
        let cases: [(String, String, String)] = [
            (
                "shortcut preference key",
                CoreConfiguration.PreferenceKeys.globalKeyboardShortcut,
                "globalKeyboardShortcut"
            ),
            (
                "Google endpoint",
                CoreConfiguration.GoogleTranslation.endpoint.absoluteString,
                "https://translate.googleapis.com/translate_a/single"
            ),
        ]
        for (name, actual, expected) in cases {
            XCTAssertEqual(actual, expected, name)
        }
    }

    func testPublicPolicyAliasesUseTypedConfiguration() {
        XCTAssertEqual(
            LanguageRoutingPolicy.maximumUnicodeScalars,
            CoreConfiguration.LanguageRouting.maximumUnicodeScalars
        )
        XCTAssertEqual(
            GoogleTranslationRequestBuilder.endpoint,
            CoreConfiguration.GoogleTranslation.endpoint
        )
        XCTAssertEqual(
            ShortcutPreferences.storageKey,
            CoreConfiguration.PreferenceKeys.globalKeyboardShortcut
        )
    }
}
