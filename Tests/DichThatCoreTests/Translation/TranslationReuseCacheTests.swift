import Testing
@testable import DichThatCore

@Test("Translation cache reuses only the last exact normalized selection")
func translationCacheReuse() {
    let output = TranslationOutput(
        sourceText: "recorder",
        text: "máy ghi âm",
        source: .english,
        target: .vietnamese
    )
    var cache = TranslationReuseCache()
    #expect(cache.output(for: "recorder") == nil)
    cache.store(output)
    #expect(cache.output(for: " recorder\n") == output)
    #expect(cache.output(for: "Recorder") == nil)
    #expect(cache.output(for: "record") == nil)
}
