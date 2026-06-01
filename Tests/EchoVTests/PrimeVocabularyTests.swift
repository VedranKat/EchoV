import XCTest
@testable import EchoV

final class PrimeVocabularyTests: XCTestCase {
    func testNormalizesAndCapsVocabularyEntriesAtFifty() {
        let entries = (0..<55).map { index in
            PrimeVocabularyEntry(term: " Term \(index) ")
        }

        let normalizedEntries = PrimeVocabularyEntry.normalizedEntries(entries)

        XCTAssertEqual(normalizedEntries.count, PrimeVocabularyEntry.maximumEntries)
        XCTAssertEqual(normalizedEntries.first?.term, "Term 0")
        XCTAssertEqual(normalizedEntries.last?.term, "Term 49")
    }

    func testAliasesSplitAndDeduplicate() {
        let aliases = PrimeVocabularyEntry.aliases(fromCommaSeparatedText: " echo vee, echo   v\necho vee, ")

        XCTAssertEqual(aliases, ["echo vee", "echo v"])
    }

    func testConservativeAliasReplacerUsesSafeMultiWordAliases() {
        let entry = PrimeVocabularyEntry(
            term: "EchoV",
            aliases: ["echo vee", "echo v"],
            aggressiveness: .conservative
        )

        let result = PrimeVocabularyAliasReplacer.replacingSafeExactAliases(
            in: "Open echo vee and then echo v.",
            entries: [entry]
        )

        XCTAssertEqual(result, "Open EchoV and then EchoV.")
    }

    func testAliasReplacerUsesSafeMultiWordAliasesForAllAggressivenessLevels() {
        let entries = [
            PrimeVocabularyEntry(term: "EchoV", aliases: ["echo vee"], aggressiveness: .balanced),
            PrimeVocabularyEntry(term: "Gemma 4", aliases: ["gemma four"], aggressiveness: .aggressive)
        ]

        let result = PrimeVocabularyAliasReplacer.replacingSafeExactAliases(
            in: "Use echo vee with gemma four.",
            entries: entries
        )

        XCTAssertEqual(result, "Use EchoV with Gemma 4.")
    }

    func testConservativeAliasReplacerSkipsOneWordAliases() {
        let entry = PrimeVocabularyEntry(
            term: "Go",
            aliases: ["go"],
            aggressiveness: .conservative
        )

        let result = PrimeVocabularyAliasReplacer.replacingSafeExactAliases(
            in: "I need to go to the store.",
            entries: [entry]
        )

        XCTAssertEqual(result, "I need to go to the store.")
    }

    func testOutputAliasReplacerUsesExplicitOneWordHeardAsVariants() {
        let entry = PrimeVocabularyEntry(
            term: "Cline",
            aliases: ["Klein"],
            aggressiveness: .conservative
        )

        let result = PrimeVocabularyAliasReplacer.replacingExactOutputAliases(
            in: "Ask Klein to review it.",
            entries: [entry]
        )

        XCTAssertEqual(result, "Ask Cline to review it.")
    }

    func testOutputAliasReplacerSkipsAliasesThatAlreadyMatchTerm() {
        let entry = PrimeVocabularyEntry(
            term: "Go",
            aliases: ["go"],
            aggressiveness: .conservative
        )

        let result = PrimeVocabularyAliasReplacer.replacingExactOutputAliases(
            in: "I need to go to the store.",
            entries: [entry]
        )

        XCTAssertEqual(result, "I need to go to the store.")
    }

    func testRiskyShortTermsAreFlagged() {
        XCTAssertTrue(PrimeVocabularyEntry(term: "Swift").isRiskyShortTerm)
        XCTAssertFalse(PrimeVocabularyEntry(term: "Gemma 4 E2B").isRiskyShortTerm)
    }

    func testValidationRejectsDuplicateTerm() {
        let failure = PrimeVocabularyEntry.validationFailure(
            term: "EchoV",
            aliasCandidates: [],
            existingEntries: [
                PrimeVocabularyEntry(term: "echov")
            ]
        )

        XCTAssertEqual(failure, .duplicateTerm("EchoV"))
    }

    func testValidationRejectsDuplicateAlias() {
        let failure = PrimeVocabularyEntry.validationFailure(
            term: "Gemma",
            aliasCandidates: ["echo vee"],
            existingEntries: [
                PrimeVocabularyEntry(term: "EchoV", aliases: ["echo vee"])
            ]
        )

        XCTAssertEqual(failure, .duplicateAlias("echo vee"))
    }

    func testValidationRejectsOversizedTermAndAlias() {
        let oversizedTerm = String(repeating: "a", count: PrimeVocabularyEntry.maximumTermLength + 1)
        let oversizedAlias = String(repeating: "b", count: PrimeVocabularyEntry.maximumAliasLength + 1)

        XCTAssertEqual(
            PrimeVocabularyEntry.validationFailure(
                term: oversizedTerm,
                aliasCandidates: [],
                existingEntries: []
            ),
            .termTooLong(PrimeVocabularyEntry.maximumTermLength)
        )
        XCTAssertEqual(
            PrimeVocabularyEntry.validationFailure(
                term: "EchoV",
                aliasCandidates: [oversizedAlias],
                existingEntries: []
            ),
            .aliasTooLong(oversizedAlias, PrimeVocabularyEntry.maximumAliasLength)
        )
    }

    func testValidationRejectsTooManyAliases() {
        let aliases = (0..<(PrimeVocabularyEntry.maximumAliases + 1)).map { "alias \($0)" }

        let failure = PrimeVocabularyEntry.validationFailure(
            term: "EchoV",
            aliasCandidates: aliases,
            existingEntries: []
        )

        XCTAssertEqual(failure, .tooManyAliases(PrimeVocabularyEntry.maximumAliases))
    }

    func testNormalizationDropsOversizedEntriesAndAliases() {
        let oversizedTerm = String(repeating: "a", count: PrimeVocabularyEntry.maximumTermLength + 1)
        let oversizedAlias = String(repeating: "b", count: PrimeVocabularyEntry.maximumAliasLength + 1)

        let entries = PrimeVocabularyEntry.normalizedEntries([
            PrimeVocabularyEntry(term: oversizedTerm),
            PrimeVocabularyEntry(term: "EchoV", aliases: [oversizedAlias, "echo vee"])
        ])

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.term, "EchoV")
        XCTAssertEqual(entries.first?.aliases, ["echo vee"])
    }
}
