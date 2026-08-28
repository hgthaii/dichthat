import AVFoundation
import DichThatCore

@MainActor
final class TranslationSpeechController {
    private let synthesizer = AVSpeechSynthesizer()
    private var state = TranslationSpeechState()

    func isVoiceAvailable(for language: SupportedLanguage) -> Bool {
        AVSpeechSynthesisVoice(language: language.speechVoiceCode) != nil
    }

    func availableVoiceCodes(for language: SupportedLanguage) -> Set<String> {
        let code = language.speechVoiceCode
        return AVSpeechSynthesisVoice(language: code) == nil ? [] : [code]
    }

    @discardableResult
    func speak(
        _ content: TranslationSpeechContent,
        target: TranslationSpeechTarget
    ) -> Bool {
        let voice = AVSpeechSynthesisVoice(
            language: content.voiceCode ?? content.language.speechVoiceCode
        )
        let actions = state.request(
            target: target,
            content: content,
            voiceAvailable: voice != nil
        )
        for action in actions {
            switch action {
            case .stop:
                synthesizer.stopSpeaking(at: .immediate)
            case let .speak(request):
                guard let voice else { continue }
                let utterance = AVSpeechUtterance(string: request.text)
                utterance.voice = voice
                synthesizer.speak(utterance)
            case .unavailable:
                return false
            }
        }
        return voice != nil
    }

    func stop() {
        for action in state.stop() where action == .stop {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
