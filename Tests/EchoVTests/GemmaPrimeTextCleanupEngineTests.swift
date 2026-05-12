import XCTest
@testable import EchoV

final class GemmaPrimeTextCleanupEngineTests: XCTestCase {
    func testUsesModelOutputWithoutDeterministicCleanup() async throws {
        let model = StubLocalTextGenerationEngine(output: "  What should I do next?  ")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)

        let cleaned = try await engine.clean(Transcript(text: "um what should I do what should I do"))

        XCTAssertEqual(cleaned.text, "What should I do next?")
    }

    func testPromptIncludesRawTranscript() async throws {
        let model = StubLocalTextGenerationEngine(output: "Cleaned")
        let engine = GemmaPrimeTextCleanupEngine(textGenerationEngine: model)

        _ = try await engine.clean(Transcript(text: "um I repeat myself"))

        let prompt = await model.lastPrompt
        XCTAssertEqual(prompt?.system.contains("EchoV Prime"), true)
        XCTAssertEqual(prompt?.user.contains("um I repeat myself"), true)
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
