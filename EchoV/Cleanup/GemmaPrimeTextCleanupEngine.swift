import Foundation

struct GemmaPrimeTextCleanupEngine: TextCleanupEngine {
    let id = "gemma-prime"
    let displayName = "Gemma Prime Cleanup"

    private let textGenerationEngine: any LocalTextGenerationEngine
    private let ownsTextGenerationEngine: Bool

    init(textGenerationEngine: any LocalTextGenerationEngine, ownsTextGenerationEngine: Bool = false) {
        self.textGenerationEngine = textGenerationEngine
        self.ownsTextGenerationEngine = ownsTextGenerationEngine
    }

    func prepare() async throws {
        try await textGenerationEngine.prepare()
    }

    func clean(_ transcript: Transcript, level: PostProcessingLevel) async throws -> CleanedText {
        try await clean(transcript, level: level, context: .empty)
    }

    func clean(_ transcript: Transcript, level: PostProcessingLevel, context: CleanupContext) async throws -> CleanedText {
        #if ECHOV_DEV_DIAGNOSTICS
        let diagnosticsRequestID = await PrimeDiagnostics.nextCleanupRequestID()
        let diagnosticsStart = Date()
        #endif
        let primedTranscript = Transcript(
            id: transcript.id,
            text: PrimeVocabularyAliasReplacer.replacingSafeExactAliases(
                in: transcript.text,
                entries: context.vocabularyEntries
            ),
            segments: transcript.segments,
            createdAt: transcript.createdAt,
            duration: transcript.duration
        )
        let prompt = PrimeCleanupPrompt(transcript: primedTranscript, level: level, context: context)
        DiagnosticLog.write(
            "Prime cleanup started engine=\(textGenerationEngine.displayName) chars=\(transcript.text.count)"
        )

        do {
            let generatedText = try await textGenerationEngine.generate(prompt: prompt.chatPrompt)
            let cleanedText = ModelOutputSanitizer.finalAnswer(from: generatedText)
            DiagnosticLog.write(
                "Prime cleanup completed engine=\(textGenerationEngine.displayName) chars=\(cleanedText.count)"
            )
            #if ECHOV_DEV_DIAGNOSTICS
            PrimeDiagnostics.writeCleanupCompleted(
                requestID: diagnosticsRequestID,
                engine: textGenerationEngine.displayName,
                inputChars: transcript.text.count,
                promptChars: prompt.chatPrompt.characterCount,
                maxTokens: prompt.chatPrompt.maxTokens,
                outputChars: cleanedText.count,
                duration: Date().timeIntervalSince(diagnosticsStart)
            )
            #endif
            return CleanedText(
                text: PrimeVocabularyAliasReplacer.replacingExactOutputAliases(
                    in: cleanedText,
                    entries: context.vocabularyEntries
                )
            )
        } catch let error as AppError {
            DiagnosticLog.write(
                "Prime cleanup AppError engine=\(textGenerationEngine.displayName) \(error.userMessage) details=\(error.technicalDetails ?? "none")"
            )
            #if ECHOV_DEV_DIAGNOSTICS
            PrimeDiagnostics.writeCleanupFailed(
                requestID: diagnosticsRequestID,
                engine: textGenerationEngine.displayName,
                inputChars: transcript.text.count,
                promptChars: prompt.chatPrompt.characterCount,
                maxTokens: prompt.chatPrompt.maxTokens,
                duration: Date().timeIntervalSince(diagnosticsStart),
                reason: "app_error"
            )
            #endif
            throw error
        } catch {
            DiagnosticLog.write(
                "Prime cleanup Error engine=\(textGenerationEngine.displayName) \(error.localizedDescription)"
            )
            #if ECHOV_DEV_DIAGNOSTICS
            PrimeDiagnostics.writeCleanupFailed(
                requestID: diagnosticsRequestID,
                engine: textGenerationEngine.displayName,
                inputChars: transcript.text.count,
                promptChars: prompt.chatPrompt.characterCount,
                maxTokens: prompt.chatPrompt.maxTokens,
                duration: Date().timeIntervalSince(diagnosticsStart),
                reason: "error"
            )
            #endif
            throw AppError.cleanupFailed(details: error.localizedDescription)
        }
    }

    func shutdown() async {
        guard ownsTextGenerationEngine else {
            return
        }

        await textGenerationEngine.shutdown()
    }
}

#if ECHOV_DEV_DIAGNOSTICS
private extension LocalChatPrompt {
    var characterCount: Int {
        system.count + user.count
    }
}
#endif
