import Foundation

enum PrimeVocabularyAggressiveness: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case conservative
    case balanced
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .conservative:
            "Conservative"
        case .balanced:
            "Balanced"
        case .aggressive:
            "Aggressive"
        }
    }

    var promptInstruction: String {
        switch self {
        case .conservative:
            "Use exact spoken aliases only. Do not infer this term from similar ordinary words."
        case .balanced:
            "Prefer this term when the transcript plausibly refers to it, especially when an alias appears."
        case .aggressive:
            "Correct likely ASR variants of this term when the surrounding context makes the intended term clear."
        }
    }
}

struct PrimeVocabularyEntry: Codable, Equatable, Identifiable, Sendable {
    static let maximumEntries = 50
    static let maximumTermLength = 80
    static let maximumAliasLength = 80
    static let maximumAliases = 6
    static let maximumPromptCharacters = 4_000

    let id: UUID
    var term: String
    var aliases: [String]
    var aggressiveness: PrimeVocabularyAggressiveness
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        term: String,
        aliases: [String] = [],
        aggressiveness: PrimeVocabularyAggressiveness = .conservative,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.term = Self.normalizedPhrase(term)
        self.aliases = Self.normalizedAliases(aliases)
        self.aggressiveness = aggressiveness
        self.isEnabled = isEnabled
    }

    var isValid: Bool {
        !term.isEmpty && term.count <= Self.maximumTermLength
    }

    var isRiskyShortTerm: Bool {
        let lowercasedTerm = term.lowercased()
        let wordCount = Self.wordCount(in: term)
        return wordCount == 1 && (term.count <= 4 || Self.commonWordTerms.contains(lowercasedTerm))
    }

    static func normalizedPhrase(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static func normalizedAliases(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let alias = normalizedPhrase(value)
            guard !alias.isEmpty, alias.count <= maximumAliasLength else {
                return nil
            }

            let key = alias.lowercased()
            guard seen.insert(key).inserted else {
                return nil
            }

            return alias
        }
        .prefix(maximumAliases)
        .map { $0 }
    }

    static func aliases(fromCommaSeparatedText text: String) -> [String] {
        normalizedAliases(aliasCandidates(fromCommaSeparatedText: text))
    }

    static func aliasCandidates(fromCommaSeparatedText text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",\n")
        return text
            .components(separatedBy: separators)
            .map(normalizedPhrase)
            .filter { !$0.isEmpty }
    }

    static func normalizedEntries(_ entries: [PrimeVocabularyEntry]) -> [PrimeVocabularyEntry] {
        var seenTerms = Set<String>()
        return entries.compactMap { entry in
            let normalized = PrimeVocabularyEntry(
                id: entry.id,
                term: entry.term,
                aliases: entry.aliases,
                aggressiveness: entry.aggressiveness,
                isEnabled: entry.isEnabled
            )
            guard normalized.isValid, normalized.aliases.allSatisfy({ $0.count <= maximumAliasLength }) else {
                return nil
            }

            let key = normalized.term.lowercased()
            guard seenTerms.insert(key).inserted else {
                return nil
            }

            return normalized
        }
        .prefix(maximumEntries)
        .map { $0 }
    }

    static func wordCount(in value: String) -> Int {
        normalizedPhrase(value)
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    private static let commonWordTerms: Set<String> = [
        "go",
        "may",
        "prime",
        "ray",
        "rust",
        "swift"
    ]
}

enum PrimeVocabularyValidationFailure: Equatable, Sendable {
    case emptyTerm
    case duplicateTerm(String)
    case duplicateAlias(String)
    case entryLimitReached
    case termTooLong(Int)
    case aliasTooLong(String, Int)
    case tooManyAliases(Int)

    var message: String {
        switch self {
        case .emptyTerm:
            "Enter a vocabulary term."
        case .duplicateTerm(let term):
            "\"\(term)\" is already in custom vocabulary."
        case .duplicateAlias(let alias):
            "\"\(alias)\" is already used as a term or heard-as variant."
        case .entryLimitReached:
            "Custom vocabulary is limited to \(PrimeVocabularyEntry.maximumEntries) terms."
        case .termTooLong(let maximumLength):
            "Terms are limited to \(maximumLength) characters."
        case .aliasTooLong(let alias, let maximumLength):
            "\"\(alias)\" is longer than the \(maximumLength)-character heard-as limit."
        case .tooManyAliases(let maximumAliases):
            "Each term can have up to \(maximumAliases) heard-as variants."
        }
    }
}

extension PrimeVocabularyEntry {
    static func validationFailure(
        term: String,
        aliasCandidates: [String],
        existingEntries: [PrimeVocabularyEntry]
    ) -> PrimeVocabularyValidationFailure? {
        let normalizedTerm = normalizedPhrase(term)
        guard !normalizedTerm.isEmpty else {
            return .emptyTerm
        }

        guard normalizedTerm.count <= maximumTermLength else {
            return .termTooLong(maximumTermLength)
        }

        let normalizedAliases = aliasCandidates
            .map(normalizedPhrase)
            .filter { !$0.isEmpty }

        var uniqueAliases: [String] = []
        var seenAliases = Set<String>()
        for alias in normalizedAliases {
            let aliasKey = alias.lowercased()
            guard seenAliases.insert(aliasKey).inserted else {
                continue
            }
            uniqueAliases.append(alias)
        }

        guard uniqueAliases.count <= maximumAliases else {
            return .tooManyAliases(maximumAliases)
        }

        if let oversizedAlias = uniqueAliases.first(where: { $0.count > maximumAliasLength }) {
            return .aliasTooLong(oversizedAlias, maximumAliasLength)
        }

        let normalizedExistingEntries = normalizedEntries(existingEntries)
        let normalizedTermKey = normalizedTerm.lowercased()
        guard !normalizedExistingEntries.contains(where: { $0.term.lowercased() == normalizedTermKey }) else {
            return .duplicateTerm(normalizedTerm)
        }

        let usedAliasesAndTerms = Set(
            normalizedExistingEntries.flatMap { entry in
                [entry.term.lowercased()] + entry.aliases.map { $0.lowercased() }
            }
        )

        if let duplicateAlias = uniqueAliases.first(where: { usedAliasesAndTerms.contains($0.lowercased()) }) {
            return .duplicateAlias(duplicateAlias)
        }

        guard normalizedExistingEntries.count < maximumEntries else {
            return .entryLimitReached
        }

        return nil
    }
}
