import Foundation

public struct TranslationReuseCache: Sendable {
    private var lastOutput: TranslationOutput?

    public init() {}

    public mutating func store(_ output: TranslationOutput) {
        lastOutput = output
    }

    public func output(for selectedText: String) -> TranslationOutput? {
        guard normalized(selectedText) == lastOutput.map({ normalized($0.sourceText) }) else {
            return nil
        }
        return lastOutput
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
