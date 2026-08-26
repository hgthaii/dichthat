import Foundation

public enum CoreConfiguration {
    public enum PreferenceKeys {
        public static let globalKeyboardShortcut = "globalKeyboardShortcut"
        public static let showSelectionIcon = "showSelectionIconWhenTextIsSelected"
    }

    public enum LanguageRouting {
        public static let maximumUnicodeScalars = 5_000
        public static let minimumConfidence = 0.55
        public static let minimumConfidenceMargin = 0.15
        public static let rescueConfidence = 0.90
        public static let rescueConfidenceMargin = 0.80
    }

    public enum GoogleTranslation {
        public static let endpoint = URL(
            string: "https://translate.googleapis.com/translate_a/single"
        )!
        public static let timeout: TimeInterval = 5
        public static let maximumAttempts = 1
    }

    public enum EnglishDictionary {
        public static let endpoint = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en")!
        public static let timeout: TimeInterval = 5
    }

    public enum MenuBarTranslation {
        public static let debounceNanoseconds: UInt64 = 650_000_000
    }

    public enum SelectionObservation {
        public static let minimumDragDistance = 4.0
    }
}
