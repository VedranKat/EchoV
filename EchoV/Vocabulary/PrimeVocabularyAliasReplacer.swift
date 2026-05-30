import Foundation

enum PrimeVocabularyAliasReplacer {
    static func replacingSafeExactAliases(in text: String, entries: [PrimeVocabularyEntry]) -> String {
        var result = text

        for entry in entries where entry.isEnabled && entry.aggressiveness == .conservative {
            for alias in entry.aliases where isSafeExactAlias(alias, for: entry) {
                result = replacing(alias: alias, with: entry.term, in: result)
            }
        }

        return result
    }

    static func isSafeExactAlias(_ alias: String, for entry: PrimeVocabularyEntry) -> Bool {
        let normalizedAlias = PrimeVocabularyEntry.normalizedPhrase(alias)
        guard !normalizedAlias.isEmpty else {
            return false
        }

        guard normalizedAlias.localizedCaseInsensitiveCompare(entry.term) != .orderedSame else {
            return false
        }

        return PrimeVocabularyEntry.wordCount(in: normalizedAlias) >= 2
    }

    private static func replacing(alias: String, with term: String, in text: String) -> String {
        let escapedAlias = NSRegularExpression.escapedPattern(for: alias)
        let pattern = #"(?i)(?<![\p{L}\p{N}])"# + escapedAlias + #"(?![\p{L}\p{N}])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        var result = text
        let range = NSRange(result.startIndex..<result.endIndex, in: result)
        let matches = regex.matches(in: result, range: range)

        for match in matches.reversed() {
            guard let replacementRange = Range(match.range, in: result) else {
                continue
            }

            result.replaceSubrange(replacementRange, with: term)
        }

        return result
    }
}
