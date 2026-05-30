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
        try await clean(transcript, level: level, context: .empty)
    }

    func clean(_ transcript: Transcript, level: PostProcessingLevel, context: CleanupContext) async throws -> CleanedText {
        let prompt = PrimeCleanupPrompt(transcript: transcript, level: level, context: context)
        let generatedText = try await textGenerationEngine.generate(prompt: prompt.chatPrompt)
        let cleanedText = ModelOutputSanitizer.finalAnswer(from: generatedText)
        return CleanedText(
            text: PrimeVocabularyAliasReplacer.replacingSafeExactAliases(
                in: cleanedText,
                entries: context.vocabularyEntries
            )
        )
    }

    func shutdown() async {
        await textGenerationEngine.shutdown()
    }
}
