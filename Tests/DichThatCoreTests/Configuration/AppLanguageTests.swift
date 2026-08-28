import Testing
@testable import DichThatCore

@Test("Vietnamese is selected from the primary system language")
func detectsVietnameseLanguage() {
    #expect(AppLanguage.detect(preferredLanguages: ["vi-VN", "en-US"]) == .vietnamese)
    #expect(AppLanguage.detect(preferredLanguages: ["vi_VN"]) == .vietnamese)
}

@Test("English is the fallback for every other system language")
func defaultsToEnglishLanguage() {
    #expect(AppLanguage.detect(preferredLanguages: ["en-US"]) == .english)
    #expect(AppLanguage.detect(preferredLanguages: ["fr-FR", "vi-VN"]) == .english)
    #expect(AppLanguage.detect(preferredLanguages: []) == .english)
}

@Test("Quick input and slogan have English and Vietnamese copy")
func localizedBrandCopyIsStable() {
    #expect(AppText.Translation.inputPlaceholder(language: .english) == "Type something ...")
    #expect(AppText.Translation.inputPlaceholder(language: .vietnamese) == "Nhập gì đó...")
    #expect(
        AppText.Settings.aboutDescription(language: .english)
            == "Translate now. Understand truly."
    )
    #expect(AppText.Settings.aboutDescription(language: .vietnamese) == "Dịch ngay. Hiểu thật.")
}

@Test("Apple Translation availability guidance is localized")
func localizedAppleTranslationGuidanceIsStable() {
    #expect(
        AppText.Errors.translationUnavailable(language: .english)
            == "Apple Translation is unavailable. Check that English and Vietnamese are installed in Translation Languages."
    )
    #expect(
        AppText.Errors.translationUnavailable(language: .vietnamese)
            == "Apple Translation chưa sẵn sàng. Hãy kiểm tra tiếng Anh và tiếng Việt đã được cài trong Ngôn ngữ dịch."
    )
}
