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
}

private actor StubLocalTextGenerationEngine: LocalTextGenerationEngine {
    let id = "stub"
    let displayName = "Stub"
    let output: String
    private(set) var lastPrompt: PrimeCleanupPrompt?

    init(output: String) {
        self.output = output
    }

    func prepare() async throws {}

    func generate(prompt: PrimeCleanupPrompt) async throws -> String {
        lastPrompt = prompt
        return output
    }
}
