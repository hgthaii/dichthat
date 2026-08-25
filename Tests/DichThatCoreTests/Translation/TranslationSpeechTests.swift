import Testing
@testable import DichThatCore

@Test("Speech chooses current source and target content")
func speechContentActions() {
    #expect(SupportedLanguage.english.speechVoiceCode == "en-US")
    #expect(SupportedLanguage.vietnamese.speechVoiceCode == "vi-VN")
    var state = TranslationSpeechState()
    let source = TranslationSpeechContent(text: "hello", language: .english)
    #expect(state.request(target: .source, content: source, voiceAvailable: true)
        == [.speak(source)])
    let target = TranslationSpeechContent(text: "xin chào", language: .vietnamese)
    #expect(state.request(target: .translation, content: target, voiceAvailable: true)
        == [.stop, .speak(target)])
    #expect(state.activeTarget == .translation)
}

@Test("Unavailable speech is nonfatal and stops prior speech")
func unavailableSpeech() {
    var state = TranslationSpeechState()
    let source = TranslationSpeechContent(text: "hello", language: .english)
    _ = state.request(target: .source, content: source, voiceAvailable: true)
    let target = TranslationSpeechContent(text: "xin chào", language: .vietnamese)
    #expect(state.request(target: .translation, content: target, voiceAvailable: false)
        == [.stop, .unavailable(.vietnamese)])
    #expect(state.activeTarget == nil)
}

@Test("Dismiss new request and termination share idempotent stop state")
func speechLifecycleStop() {
    var state = TranslationSpeechState()
    let content = TranslationSpeechContent(text: "hello", language: .english)
    _ = state.request(target: .source, content: content, voiceAvailable: true)
    #expect(state.stop() == [.stop])
    #expect(state.stop().isEmpty)
    #expect(state.activeTarget == nil)
}
