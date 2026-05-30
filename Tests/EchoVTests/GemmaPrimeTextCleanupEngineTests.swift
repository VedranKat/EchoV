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
        XCTAssertEqual(prompt?.user.contains("Target app: Xcode (com.apple.dt.Xcode)"), true)
        XCTAssertEqual(prompt?.user.contains("Formatting profile: Code"), true)
        XCTAssertEqual(prompt?.user.contains("EchoV | aliases: echo vee"), true)
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
