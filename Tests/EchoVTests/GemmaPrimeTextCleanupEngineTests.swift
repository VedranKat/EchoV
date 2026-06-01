import XCTest
@testable import EchoV

final class GemmaPrimeTextCleanupEngineTests: XCTestCase {
    func testUsesModelOutputWithoutDeterministicCleanup() async throws {
        let model = StubLocalTextGenerationEngine(output: "  What should I do next?  ")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)

        let cleaned = try await engine.clean(
            Transcript(text: "um what should I do what should I do"),
            level: .balanced
        )

        XCTAssertEqual(cleaned.text, "What should I do next?")
    }

    func testStripsReasoningFromModelOutput() async throws {
        let model = StubLocalTextGenerationEngine(output: "<think>Hidden cleanup reasoning.</think>\nCleaned text.")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)

        let cleaned = try await engine.clean(
            Transcript(text: "clean this"),
            level: .balanced
        )

        XCTAssertEqual(cleaned.text, "Cleaned text.")
    }

    func testPromptIncludesRawTranscript() async throws {
        let model = StubLocalTextGenerationEngine(output: "Cleaned")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)

        _ = try await engine.clean(Transcript(text: "um I repeat myself"), level: .minimal)

        let prompt = await model.lastPrompt
        XCTAssertEqual(prompt?.system.contains("EchoV Prime"), true)
        XCTAssertEqual(prompt?.system.contains("smallest possible edits"), true)
        XCTAssertEqual(prompt?.user.contains("um I repeat myself"), true)
    }

    func testConciseLevelRequestsShortDirectOutput() async throws {
        let model = StubLocalTextGenerationEngine(output: "Short output")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)

        _ = try await engine.clean(Transcript(text: "I think maybe we should just go ahead"), level: .concise)

        let prompt = await model.lastPrompt
        XCTAssertEqual(prompt?.system.contains("short, direct text"), true)
    }

    func testBalancedPromptForLongTranscriptForbidsSummarization() async throws {
        let model = StubLocalTextGenerationEngine(output: "Cleaned")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)
        let transcript = """
        I had a word appear that was heard incorrectly, and Prime actually typed the exact word that I had in the vocabulary section. The whole point was that the heard-as variant should correct the ASR spelling, but it should not show up in the output. I need that detail preserved because otherwise the report makes it sound like the feature failed in a different way.
        """

        _ = try await engine.clean(Transcript(text: transcript), level: .balanced)

        let prompt = await model.lastPrompt
        XCTAssertEqual(prompt?.user.contains(transcript), true)
        XCTAssertEqual(
            prompt?.system.contains("natural, ready-to-insert text"),
            true
        )
        XCTAssertEqual(
            prompt?.system.contains("Preserve all substantive content, sentence order, examples, caveats, and follow-up details."),
            true
        )
        XCTAssertEqual(
            prompt?.system.contains("Actively remove filler words, false starts, repeated phrases, meaningless hedging, and obvious ASR artifacts."),
            true
        )
        XCTAssertEqual(
            prompt?.system.contains("Do not summarize, truncate, answer, or collapse the transcript into a shorter statement."),
            true
        )
        XCTAssertEqual(
            prompt?.system.contains("Use light rewriting to make the result read like deliberate text"),
            true
        )
        XCTAssertEqual(prompt?.system.contains("concise, readable text"), false)
    }

    func testConcisePromptPreservesRequiredDetails() async throws {
        let model = StubLocalTextGenerationEngine(output: "Short output")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)

        _ = try await engine.clean(Transcript(text: "Summarize nothing important, but make this cleaner."), level: .concise)

        let prompt = await model.lastPrompt
        XCTAssertEqual(
            prompt?.system.contains("Shortening must preserve required facts, examples, caveats, names, technical terms, numbers, and formatting."),
            true
        )
        XCTAssertEqual(prompt?.system.contains("do not drop required facts, examples, or caveats"), true)
    }

    func testPromptIncludesAppContextAndVocabulary() async throws {
        let model = StubLocalTextGenerationEngine(output: "Use EchoV.")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)
        let context = CleanupContext(
            targetApplication: TargetAppContext(localizedName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
            appFormattingProfile: .code,
            vocabularyEntries: [
                PrimeVocabularyEntry(term: "EchoV", aliases: ["echo vee"], aggressiveness: .conservative)
            ]
        )

        _ = try await engine.clean(Transcript(text: "use echo vee"), level: .minimal, context: context)

        let prompt = await model.lastPrompt
        XCTAssertEqual(
            prompt?.system.contains("Apply any formatting profile conservatively when choosing punctuation, line breaks, capitalization, command/code preservation, and paragraph shape."),
            true
        )
        XCTAssertEqual(prompt?.user.contains("Target app: Xcode (com.apple.dt.Xcode)"), true)
        XCTAssertEqual(prompt?.user.contains("Formatting profile: Code"), true)
        XCTAssertEqual(prompt?.user.contains("EchoV | heard as: echo vee"), true)
    }

    func testBalancedPromptIncludesAppAwareFormattingRulesForManualScenarios() async throws {
        let scenarios: [(app: TargetAppContext, profile: AppFormattingProfile, transcript: String)] = [
            (
                TargetAppContext(localizedName: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"),
                .chat,
                "hey quick update um I tuned balanced a little bit so it should clean the obvious junk but not turn the whole thing into corporate email"
            ),
            (
                TargetAppContext(localizedName: "Mail", bundleIdentifier: "com.apple.mail"),
                .email,
                "quick update um I tuned balanced mode so it should remove obvious dictation artifacts while preserving the details from the original message"
            ),
            (
                TargetAppContext(localizedName: "Terminal", bundleIdentifier: "com.apple.Terminal"),
                .terminal,
                "git status dash dash short new line git diff dash dash stat new line swift test dash dash filter gemma prime text cleanup engine tests"
            ),
            (
                TargetAppContext(localizedName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode"),
                .code,
                "call fetch user by id open paren user id colon user dot id close paren and make sure api client stays capitalized as APIClient"
            )
        ]

        for scenario in scenarios {
            XCTAssertEqual(AppFormattingProfile.profile(for: scenario.app), scenario.profile)

            let model = StubLocalTextGenerationEngine(output: "Cleaned")
            let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)
            let context = CleanupContext(
                targetApplication: scenario.app,
                appFormattingProfile: scenario.profile
            )

            _ = try await engine.clean(Transcript(text: scenario.transcript), level: .balanced, context: context)

            let capturedPrompt = await model.lastPrompt
            let prompt = try XCTUnwrap(capturedPrompt)
            XCTAssertEqual(prompt.user.contains(scenario.transcript), true)
            XCTAssertEqual(prompt.user.contains("Target app: \(scenario.app.displayName)"), true)
            XCTAssertEqual(prompt.user.contains("Formatting profile: \(scenario.profile.title)"), true)
            XCTAssertEqual(prompt.user.contains("Formatting rule: \(scenario.profile.promptInstruction)"), true)
            XCTAssertEqual(prompt.system.contains("natural, ready-to-insert text"), true)
            XCTAssertEqual(prompt.system.contains("Actively remove filler words, false starts, repeated phrases, meaningless hedging, and obvious ASR artifacts."), true)
            XCTAssertEqual(prompt.system.contains("Apply any formatting profile conservatively"), true)
        }
    }

    func testSafeAliasesAreAppliedBeforePrompt() async throws {
        let model = StubLocalTextGenerationEngine(output: "Use EchoV today.")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)
        let context = CleanupContext(
            vocabularyEntries: [
                PrimeVocabularyEntry(term: "EchoV", aliases: ["echo vee"], aggressiveness: .conservative)
            ]
        )

        _ = try await engine.clean(Transcript(text: "use echo vee today"), level: .balanced, context: context)

        let prompt = await model.lastPrompt
        XCTAssertEqual(prompt?.user.contains("use EchoV today"), true)
        XCTAssertEqual(prompt?.user.contains("use echo vee today"), false)
    }

    func testConservativeAliasesAreReplacedAfterModelOutput() async throws {
        let model = StubLocalTextGenerationEngine(output: "Use echo vee today.")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)
        let context = CleanupContext(
            vocabularyEntries: [
                PrimeVocabularyEntry(term: "EchoV", aliases: ["echo vee"], aggressiveness: .conservative)
            ]
        )

        let cleaned = try await engine.clean(Transcript(text: "use echo vee today"), level: .balanced, context: context)

        XCTAssertEqual(cleaned.text, "Use EchoV today.")
    }

    func testOneWordHeardAsAliasesAreReplacedAfterModelOutput() async throws {
        let model = StubLocalTextGenerationEngine(output: "Ask Klein to review it.")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)
        let context = CleanupContext(
            vocabularyEntries: [
                PrimeVocabularyEntry(term: "Cline", aliases: ["Klein"], aggressiveness: .conservative)
            ]
        )

        let cleaned = try await engine.clean(Transcript(text: "ask cline to review it"), level: .balanced, context: context)

        XCTAssertEqual(cleaned.text, "Ask Cline to review it.")
    }

    func testOneWordConservativeAliasesAreNotReplacedAfterModelOutput() async throws {
        let model = StubLocalTextGenerationEngine(output: "I need to go now.")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)
        let context = CleanupContext(
            vocabularyEntries: [
                PrimeVocabularyEntry(term: "Go", aliases: ["go"], aggressiveness: .conservative)
            ]
        )

        let cleaned = try await engine.clean(Transcript(text: "I need to go now"), level: .balanced, context: context)

        XCTAssertEqual(cleaned.text, "I need to go now.")
    }

    func testPromptCapsVocabularySection() async throws {
        let model = StubLocalTextGenerationEngine(output: "Cleaned")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)
        let entries = (0..<PrimeVocabularyEntry.maximumEntries).map { index in
            PrimeVocabularyEntry(
                term: "Term \(index) \(String(repeating: "a", count: 60))",
                aliases: (0..<PrimeVocabularyEntry.maximumAliases).map { aliasIndex in
                    "alias \(index) \(aliasIndex) \(String(repeating: "b", count: 60))"
                }
            )
        }
        let context = CleanupContext(vocabularyEntries: entries)

        _ = try await engine.clean(Transcript(text: "clean this"), level: .balanced, context: context)

        let user = await model.lastPrompt?.user ?? ""
        let marker = "Custom vocabulary:\n"
        guard
            let markerRange = user.range(of: marker),
            let transcriptRange = user[markerRange.upperBound...].range(of: "\n\nTranscript:")
        else {
            return XCTFail("Expected vocabulary and transcript sections in Prime prompt.")
        }

        let vocabularySection = String(user[markerRange.upperBound..<transcriptRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertLessThanOrEqual(vocabularySection.count, PrimeVocabularyEntry.maximumPromptCharacters)
    }

    func testLongTranscriptGetsLargerGenerationBudget() async throws {
        let model = StubLocalTextGenerationEngine(output: "Cleaned")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)
        let transcript = String(repeating: "This is a longer dictated sentence. ", count: 28)

        _ = try await engine.clean(Transcript(text: transcript), level: .balanced)

        let prompt = await model.lastPrompt
        XCTAssertGreaterThanOrEqual(prompt?.maxTokens ?? 0, 1536)
    }
}

private actor StubLocalTextGenerationEngine: LocalTextGenerationEngine {
    let id = "stub"
    let displayName = "Stub"
    let output: String
    private(set) var lastPrompt: LocalChatPrompt?

    init(output: String) {
        self.output = output
    }

    func prepare() async throws {}

    func generate(prompt: LocalChatPrompt) async throws -> String {
        lastPrompt = prompt
        return output
    }
}
