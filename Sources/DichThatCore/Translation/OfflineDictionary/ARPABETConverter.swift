import Foundation

public enum ARPABETConverter {
    public static func ipa(from pronunciation: String) -> String? {
        let tokens = pronunciation
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !tokens.isEmpty else { return nil }
        let vowelCount = tokens.count { rawToken in
            vowels.contains(String(rawToken.prefix { !$0.isNumber }))
        }

        var output = ""
        for (index, rawToken) in tokens.enumerated() {
            let stress = rawToken.last.flatMap { $0.isNumber ? Int(String($0)) : nil }
            let token = stress == nil ? rawToken : String(rawToken.dropLast())
            guard let value = symbols[token] else { return nil }

            if let stress, stress > 0, vowelCount > 1 {
                let marker = stress == 1 ? "ˈ" : "ˌ"
                let insertionIndex = syllableStart(in: output, preceding: tokens[..<index])
                output.insert(contentsOf: marker, at: insertionIndex)
            }
            output += vowel(token, stress: stress) ?? value
        }
        return output.isEmpty ? nil : "/\(output)/"
    }

    private static func syllableStart(
        in output: String,
        preceding: ArraySlice<String>
    ) -> String.Index {
        guard let lastVowelIndex = preceding.lastIndex(where: { token in
            vowels.contains(String(token.prefix { !$0.isNumber }))
        }) else { return output.startIndex }

        let consonants = preceding[preceding.index(after: lastVowelIndex)...].map {
            String($0.prefix { !$0.isNumber })
        }
        guard !consonants.isEmpty else { return output.endIndex }
        let suffix = consonants.suffix(1).compactMap { symbols[$0] }.joined()
        return output.index(output.endIndex, offsetBy: -suffix.count)
    }

    private static func vowel(_ token: String, stress: Int?) -> String? {
        switch token {
        case "AH": return stress == 0 ? "ə" : "ʌ"
        case "ER": return stress == 0 ? "ɚ" : "ɝ"
        default: return nil
        }
    }

    private static let vowels: Set<String> = [
        "AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY",
        "IH", "IY", "OW", "OY", "UH", "UW",
    ]

    private static let symbols: [String: String] = [
        "AA": "ɑ", "AE": "æ", "AH": "ʌ", "AO": "ɔ", "AW": "aʊ",
        "AY": "aɪ", "EH": "ɛ", "ER": "ɝ", "EY": "eɪ", "IH": "ɪ",
        "IY": "i", "OW": "oʊ", "OY": "ɔɪ", "UH": "ʊ", "UW": "u",
        "B": "b", "CH": "tʃ", "D": "d", "DH": "ð", "F": "f",
        "G": "ɡ", "HH": "h", "JH": "dʒ", "K": "k", "L": "l",
        "M": "m", "N": "n", "NG": "ŋ", "P": "p", "R": "ɹ",
        "S": "s", "SH": "ʃ", "T": "t", "TH": "θ", "V": "v",
        "W": "w", "Y": "j", "Z": "z", "ZH": "ʒ",
    ]
}
