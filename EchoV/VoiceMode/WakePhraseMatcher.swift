import Foundation

enum WakePhraseMatcher {
    static let activationPhrase = "computer"

    static func isActivationPhrase(_ text: String) -> Bool {
        normalizedTokens(in: text) == [activationPhrase]
    }

    private static func normalizedTokens(in text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let normalizedScalars = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }

        return String(normalizedScalars)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }
}
