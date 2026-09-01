private func localized(_ english: String, _ vietnamese: String) -> String {
    AppLanguage.current.localized(english: english, vietnamese: vietnamese)
}

public enum AppText {
    public enum Menu {
        public static var grantAccessibility: String {
            grantAccessibility(language: .current)
        }
        public static func grantAccessibility(language: AppLanguage) -> String {
            language.localized(
                english: "Grant Accessibility Access…",
                vietnamese: "Cấp quyền Trợ năng…"
            )
        }
        public static var checkForUpdates: String {
            checkForUpdates(language: .current)
        }
        public static func checkForUpdates(language: AppLanguage) -> String {
            language.localized(
                english: "Check for Updates…",
                vietnamese: "Kiểm tra bản cập nhật…"
            )
        }
        public static var settings: String { settings(language: .current) }
        public static func settings(language: AppLanguage) -> String {
            language.localized(english: "Settings…", vietnamese: "Cài đặt…")
        }
        public static var quitPrefix: String { quitPrefix(language: .current) }
        public static func quitPrefix(language: AppLanguage) -> String {
            language.localized(english: "Quit", vietnamese: "Thoát")
        }
        public static var accessibilityRequiredSuffix: String {
            accessibilityRequiredSuffix(language: .current)
        }
        public static func accessibilityRequiredSuffix(language: AppLanguage) -> String {
            language.localized(
                english: "Accessibility permission required",
                vietnamese: "Cần quyền Trợ năng"
            )
        }
    }

    public enum Translation {
        public static var loading: String { localized("Translating…", "Đang dịch…") }
        public static var failureTitle: String { localized("Couldn’t translate", "Không thể dịch") }
        public static var meanings: String { localized("Meanings", "Nghĩa") }
        public static var pronunciationUnavailable: String {
            localized("Pronunciation unavailable", "Không có cách phát âm")
        }
        public static var englishSynonyms: String { localized("Synonyms", "Từ đồng nghĩa") }
        public static var inputPlaceholder: String {
            inputPlaceholder(language: .current)
        }
        public static func inputPlaceholder(language: AppLanguage) -> String {
            language.localized(english: "Type something ...", vietnamese: "Nhập gì đó...")
        }
        public static var closeAccessibility: String {
            localized("Close translation", "Đóng bản dịch")
        }
        public static var pronunciationSpeechAccessibility: String {
            localized("Play US pronunciation", "Nghe phát âm Anh–Mỹ")
        }
        public static var sourceTextSpeechAccessibility: String {
            localized("Pronounce source text", "Phát âm nội dung gốc")
        }
        public static var voiceUnavailable: String {
            localized("System voice unavailable", "Không có giọng đọc hệ thống")
        }
    }

    public enum Settings {
        public static var windowTitle: String { localized("DichThat Settings", "Cài đặt DichThat") }
        public static var general: String { localized("General", "Chung") }
        public static var about: String { localized("About", "Giới thiệu") }
        public static var accessibilityTitle: String {
            localized("Accessibility Access Required", "Yêu cầu quyền Trợ năng")
        }
        public static var accessibilityDescription: String {
            localized(
                "Allow DichThat to read chosen text globally for instant translation shortcuts.",
                "Cho phép DichThat đọc văn bản bạn chọn trên toàn hệ thống để dịch nhanh."
            )
        }
        public static var grantAccess: String {
            localized("Grant Access in Settings", "Mở Cài đặt để cấp quyền")
        }
        public static var translationLanguagesTitle: String {
            localized("Translation languages required", "Cần tải ngôn ngữ dịch")
        }
        public static var translationLanguagesDescription: String {
            localized(
                "English and Vietnamese will download when you translate for the first time.",
                "Tiếng Anh và tiếng Việt sẽ được tải khi bạn dịch lần đầu."
            )
        }
        public static var downloadTranslationLanguages: String {
            localized("Download", "Tải xuống")
        }
        public static var downloadingTranslationLanguages: String {
            localized("Downloading English and Vietnamese…", "Đang tải tiếng Anh và tiếng Việt…")
        }
        public static var translationLanguageDownloadFailed: String {
            localized(
                "Couldn’t download the translation languages. Try again.",
                "Không thể tải ngôn ngữ dịch. Hãy thử lại."
            )
        }
        public static var shortcutTitle: String { localized("Quick Translate", "Dịch nhanh") }
        public static var shortcutSubtitle: String {
            localized(
                "Translate the text currently selected in another app",
                "Dịch nhanh văn bản đang chọn trong ứng dụng khác"
            )
        }
        public static var inputShortcutTitle: String {
            localized("Translation Input", "Nhập nội dung để dịch")
        }
        public static var inputShortcutSubtitle: String {
            localized(
                "Open the translation input from anywhere",
                "Mở ô nhập nội dung dịch từ bất kỳ đâu"
            )
        }
        public static var shortcutKeyAccessibility: String {
            localized("Shortcut letter or number", "Chữ hoặc số của phím tắt")
        }
        public static var shortcutKeyPlaceholder: String { localized("KEY", "PHÍM") }
        public static var launchAtLoginTitle: String {
            localized("Launch at login", "Khởi động cùng macOS")
        }
        public static var launchAtLoginSubtitle: String {
            localized(
                "Start automatically when you sign in to macOS",
                "Tự động mở khi bạn đăng nhập macOS"
            )
        }
        public static var contextTranslationTitle: String {
            localized("Context-aware translation", "Dịch theo ngữ cảnh")
        }
        public static var contextTranslationSubtitle: String {
            localized(
                "Use surrounding text for more accurate translations",
                "Dùng nội dung xung quanh để bản dịch chính xác hơn"
            )
        }
        public static var comingSoon: String { localized("COMING SOON", "SẮP RA MẮT") }
        public static var reportABug: String { localized("Report a Bug", "Báo lỗi") }
        public static var dataSourcesTab: String { localized("Data", "Dữ liệu") }
        public static var dataSources: String { localized("Data Sources", "Nguồn dữ liệu") }
        public static var dataSourcesDescription: String {
            localized(
                "Integrated dictionaries and translation providers used by DichThat",
                "Các từ điển và dịch vụ dịch thuật được DichThat sử dụng"
            )
        }
        public static var dataSourcesUnavailable: String {
            localized("Data source information is unavailable.", "Không thể tải thông tin nguồn dữ liệu.")
        }
        public static var versionPrefix: String { localized("Version", "Phiên bản") }
        public static var aboutDescription: String {
            aboutDescription(language: .current)
        }
        public static func aboutDescription(language: AppLanguage) -> String {
            language.localized(
                english: "Translate. Stay in flow.",
                vietnamese: "Dịch ngay nơi bạn đọc"
            )
        }
        public static var startupError: String {
            localized(
                "Couldn’t update the launch-at-login setting.",
                "Không thể cập nhật cài đặt mở khi đăng nhập."
            )
        }
        public static var startupApprovalRequired: String {
            localized(
                "Allow DichThat in System Settings → General → Login Items.",
                "Cho phép DichThat trong Cài đặt hệ thống → Cài đặt chung → Mục đăng nhập."
            )
        }
        public static func shortcutRegistrationFailed(_ detail: String) -> String {
            localized("Shortcut registration failed", "Đăng ký phím tắt thất bại") + ": \(detail)"
        }

        public static func shortcutUpdateFailed(_ detail: String) -> String {
            localized("Shortcut update failed", "Cập nhật phím tắt thất bại") + ": \(detail)"
        }

        public static func shortcutUnavailable(_ detail: String) -> String {
            localized("Could not use shortcut", "Không thể dùng phím tắt") + ": \(detail)"
        }

        public static func shortcutConflict(_ shortcut: String, usedBy feature: String) -> String {
            localized(
                "\(shortcut) is used by \(feature). Choose another.",
                "\(shortcut) đang dùng cho \(feature). Chọn phím khác."
            )
        }
    }

    public enum Updates {
        public static var title: String { localized("Software Update", "Cập nhật phần mềm") }
        public static var checkForUpdates: String {
            localized("Check for Updates", "Kiểm tra cập nhật")
        }
        public static var checking: String { localized("Checking…", "Đang kiểm tra…") }
        public static var checkingDetail: String {
            localized("Checking for a new version…", "Đang kiểm tra phiên bản mới…")
        }
        public static var updateNow: String { localized("Update Now", "Cập nhật ngay") }
        public static var upToDate: String {
            localized("DichThat is up to date", "DichThat đã được cập nhật")
        }
        public static var lastCheckedNever: String {
            localized("Never checked", "Chưa từng kiểm tra")
        }
        public static var lastCheckedJustNow: String {
            localized("Last checked just now", "Vừa kiểm tra")
        }
        public static var lastCheckedPrefix: String {
            localized("Last checked", "Đã kiểm tra")
        }
        public static var failed: String {
            localized("Couldn’t check for updates", "Không thể kiểm tra cập nhật")
        }
        public static var checkUnavailable: String {
            localized(
                "Another update operation is already running",
                "Một tác vụ cập nhật khác đang chạy"
            )
        }

        public static func available(version: String) -> String {
            localized("Version \(version) is available", "Đã có phiên bản \(version)")
        }
    }

    public enum Installation {
        public static var title: String {
            localized("Move DichThat to Applications", "Di chuyển DichThat vào Applications")
        }
        public static var message: String {
            localized(
                "DichThat can’t run reliably from the installer. Drag it to Applications, then open it there.",
                "DichThat không thể hoạt động ổn định từ bộ cài. Hãy kéo app vào Applications rồi mở từ đó."
            )
        }
        public static var openApplications: String {
            localized("Open Applications", "Mở Applications")
        }
        public static var quit: String { localized("Quit", "Thoát") }
    }

    public enum Errors {
        public static var applicationUnavailable: String {
            localized("Application is unavailable.", "Ứng dụng hiện không khả dụng.")
        }
        public static var accessibilityRequired: String {
            localized("Accessibility access is required", "Cần cấp quyền Trợ năng")
        }
        public static var captureInProgress: String {
            localized("Selection capture is already in progress", "Đang đọc nội dung được chọn")
        }
        public static var noText: String { localized("No text to translate", "Không có nội dung để dịch") }
        public static var supportedLanguages: String {
            localized(
                "Only English and Vietnamese are supported",
                "Chỉ hỗ trợ tiếng Anh và tiếng Việt"
            )
        }
        public static var ambiguousLanguage: String {
            localized(
                "Couldn’t confidently detect English or Vietnamese",
                "Không thể xác định rõ tiếng Anh hoặc tiếng Việt"
            )
        }
        public static var cancelled: String { localized("Translation cancelled", "Đã huỷ dịch") }
        public static var translationUnavailable: String {
            translationUnavailable(language: .current)
        }
        public static func translationUnavailable(language: AppLanguage) -> String {
            language.localized(
                english: "Apple Translation is unavailable. Check that English and Vietnamese are installed in Translation Languages.",
                vietnamese: "Apple Translation chưa sẵn sàng. Hãy kiểm tra tiếng Anh và tiếng Việt đã được cài trong Ngôn ngữ dịch."
            )
        }
        public static var invalidResponse: String {
            localized("Translation response was invalid", "Phản hồi dịch không hợp lệ")
        }
        public static var unsupportedResponseLanguage: String {
            localized("Detected language is not supported", "Ngôn ngữ phát hiện không được hỗ trợ")
        }
        public static var sourceLanguageChanged: String {
            localized(
                "Language detection changed; please try again",
                "Kết quả nhận diện ngôn ngữ đã thay đổi; hãy thử lại"
            )
        }

        public static func inputTooLong(maximum: Int) -> String {
            localized(
                "Selection exceeds \(maximum) Unicode scalars",
                "Nội dung được chọn vượt quá \(maximum) ký tự Unicode"
            )
        }

    }

    public enum ShortcutErrors {
        public static var persistenceUnavailable: String {
            localized("Preferences unavailable", "Không thể lưu tuỳ chọn")
        }
        public static var unsupportedModifiers: String {
            localized(
                "Choose only Control, Option, Command, or Shift.",
                "Chỉ chọn Control, Option, Command hoặc Shift."
            )
        }
        public static var requiresPrimaryModifier: String {
            localized(
                "Choose at least Control, Option, or Command.",
                "Chọn ít nhất Control, Option hoặc Command."
            )
        }
        public static var unusableKey: String {
            localized(
                "Choose one letter A–Z or number 0–9.",
                "Chọn một chữ cái A–Z hoặc số 0–9."
            )
        }
    }
}
