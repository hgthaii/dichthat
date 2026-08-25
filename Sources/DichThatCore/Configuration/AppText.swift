public enum AppText {
    public enum Menu {
        public static let grantAccessibility = "Grant Accessibility Access…"
        public static let settings = "Settings…"
        public static let quitPrefix = "Quit"
        public static let accessibilityRequiredSuffix = "Accessibility permission required"
    }

    public enum Translation {
        public static let loading = "Translating…"
        public static let failureTitle = "Couldn’t translate"
        public static let meanings = "Meanings"
        public static let pronunciationUnavailable = "Pronunciation unavailable"
        public static let englishSynonyms = "Synonyms"
        public static let inputPlaceholder = "Type English or Vietnamese…"
        public static let inputPrompt = "Start typing to translate automatically"
        public static let closeAccessibility = "Close translation"
        public static let sourceWordSpeechAccessibility = "Pronounce source word"
        public static let sourceTextSpeechAccessibility = "Pronounce source text"
        public static let voiceUnavailable = "System voice unavailable"
    }

    public enum Settings {
        public static let windowTitle = "DichThat Settings"
        public static let general = "General"
        public static let about = "About"
        public static let accessibilityTitle = "Accessibility access required"
        public static let accessibilityDescription = "Allow DichThat to read the text you select in other apps."
        public static let grantAccess = "Grant Access"
        public static let openSettings = "Open Settings"
        public static let shortcutTitle = "Shortcut"
        public static let shortcutSubtitle = "Choose modifiers and one A–Z or 0–9 key"
        public static let shortcutKeyAccessibility = "Shortcut letter or number"
        public static let selectionTitle = "Selection icon"
        public static let selectionSubtitle = "Show after dragging to select text"
        public static let launchAtLoginTitle = "Launch at login"
        public static let launchAtLoginSubtitle = "Start DichThat automatically when you sign in"
        public static let checkForUpdates = "Check for Updates"
        public static let checkingForUpdates = "Checking…"
        public static let upToDate = "You’re using the latest version."
        public static let updateUnavailable = "Couldn’t check for updates."
        public static let updateAvailableSuffix = "is available."
        public static let openRelease = "Open Release"
        public static let projectWebsite = "Project Website"
        public static let reportABug = "Report a Bug"
        public static let versionPrefix = "Version"
        public static let aboutDescription = "Fast English ↔ Vietnamese translation from anywhere on macOS."
        public static let startupError = "Couldn’t update the launch-at-login setting."
        public static let startupApprovalRequired = "Allow DichThat in System Settings → General → Login Items."
        public static let record = "Record"
        public static let typeShortcut = "Type shortcut"
        public static let escapeToCancel = "Esc to cancel"
        public static let saved = "Saved"
        public static let shortcutRecorderAccessibility = "Keyboard shortcut recorder"
        public static let unsupportedShortcut = "Unsupported"
        public static let addShortcutModifier = "Add ⌘, ⌥, or ⌃"
        public static let chooseAnotherKey = "Choose another key"
    }

    public enum Errors {
        public static let applicationUnavailable = "Application is unavailable."
        public static let accessibilityRequired = "Accessibility access is required"
        public static let captureInProgress = "Selection capture is already in progress"
        public static let noText = "No text to translate"
        public static let supportedLanguages = "Only English and Vietnamese are supported"
        public static let ambiguousLanguage = "Couldn’t confidently detect English or Vietnamese"
        public static let cancelled = "Translation cancelled"
        public static let timedOut = "Translation timed out"
        public static let serviceUnavailable = "Translation service unavailable"
        public static let invalidResponse = "Translation response was invalid"
        public static let unsupportedResponseLanguage = "Detected language is not supported"
        public static let sourceLanguageChanged = "Language detection changed; please try again"
    }

    public enum PartOfSpeech {
        public static let localized: [String: String] = [
            "noun": "danh từ",
            "adjective": "tính từ",
            "verb": "động từ",
            "adverb": "trạng từ",
            "pronoun": "đại từ",
            "preposition": "giới từ",
            "conjunction": "liên từ",
            "interjection": "thán từ",
            "exclamation": "thán từ",
            "determiner": "từ hạn định",
            "article": "mạo từ",
            "numeral": "số từ",
        ]
    }
}
