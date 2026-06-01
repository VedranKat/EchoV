import Foundation

enum PrimeVocabularyAliasReplacer {
    static func replacingSafeExactAliases(in text: String, entries: [PrimeVocabularyEntry]) -> String {
        replacingAliases(in: text, entries: entries, isEligible: isSafeExactAlias)
    }

    static func replacingExactOutputAliases(in text: String, entries: [PrimeVocabularyEntry]) -> String {
        replacingAliases(in: text, entries: entries, isEligible: isExactOutputAlias)
    }

    static func isSafeExactAlias(_ alias: String, for entry: PrimeVocabularyEntry) -> Bool {
        isExactOutputAlias(alias, for: entry)
            && PrimeVocabularyEntry.wordCount(in: alias) >= 2
    }

    static func isExactOutputAlias(_ alias: String, for entry: PrimeVocabularyEntry) -> Bool {
        let normalizedAlias = PrimeVocabularyEntry.normalizedPhrase(alias)
        guard !normalizedAlias.isEmpty else {
            return false
        }

        return normalizedAlias.localizedCaseInsensitiveCompare(entry.term) != .orderedSame
    }

    private static func replacingAliases(
        in text: String,
        entries: [PrimeVocabularyEntry],
        isEligible: (String, PrimeVocabularyEntry) -> Bool
    ) -> String {
        var result = text

        let replacements = entries
            .filter(\.isEnabled)
            .flatMap { entry in
                entry.aliases
                    .filter { isEligible($0, entry) }
                    .map { alias in AliasReplacement(alias: alias, term: entry.term) }
            }
            .sorted { first, second in first.alias.count > second.alias.count }

        for replacement in replacements {
            result = replacing(alias: replacement.alias, with: replacement.term, in: result)
        }

        return result
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

private struct AliasReplacement {
    let alias: String
    let term: String
}
