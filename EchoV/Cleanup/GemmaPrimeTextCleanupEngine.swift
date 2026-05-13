import Foundation

struct GemmaPrimeTextCleanupEngine: TextCleanupEngine {
    let id = "gemma-prime"
    let displayName = "Gemma Prime Cleanup"

    private let textGenerationEngine: any LocalTextGenerationEngine

    init(textGenerationEngine: any LocalTextGenerationEngine) {
        self.textGenerationEngine = textGenerationEngine
    }

    func prepare() async throws {
        try await textGenerationEngine.prepare()
    }

    func clean(_ transcript: Transcript, level: PostProcessingLevel) async throws -> CleanedText {
        let prompt = PrimeCleanupPrompt(transcript: transcript, level: level)
        let generatedText = try await textGenerationEngine.generate(prompt: prompt)
        return CleanedText(text: generatedText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func shutdown() async {
        await textGenerationEngine.shutdown()
    }
}
