import Foundation

struct LiveSubtitlePostProcessor: Sendable {
    private let textGenerationEngine: any LocalTextGenerationEngine

    init(textGenerationEngine: any LocalTextGenerationEngine) {
        self.textGenerationEngine = textGenerationEngine
    }

    func process(
        text: String,
        mode: LiveSubtitleMode,
        targetLanguage: String
    ) async throws -> String {
        guard mode.requiresPostProcessing else {
            return text
        }

        let prompt = LiveSubtitlePrompt(
            text: text,
            mode: mode,
            targetLanguage: targetLanguage
        )
        let generatedText = try await textGenerationEngine.generate(prompt: prompt.chatPrompt)
        return Self.sanitizedSubtitle(ModelOutputSanitizer.finalAnswer(from: generatedText))
    }

    static func sanitizedSubtitle(_ text: String) -> String {
        var sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let removablePrefixes = [
            "Subtitle:",
            "Subtitles:",
            "Caption:",
            "Captions:",
            "Translation:",
            "Translated subtitle:",
            "Cleaned subtitle:"
        ]

        for prefix in removablePrefixes {
            if sanitized.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil {
                sanitized = String(sanitized.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        if sanitized.hasPrefix("\""), sanitized.hasSuffix("\""), sanitized.count >= 2 {
            sanitized = String(sanitized.dropFirst().dropLast())
        }

        return sanitized
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LiveSubtitlePrompt: Equatable, Sendable {
    let chatPrompt: LocalChatPrompt

    init(text: String, mode: LiveSubtitleMode, targetLanguage: String) {
        let trimmedTargetLanguage = targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        let language = trimmedTargetLanguage.isEmpty ? "English" : trimmedTargetLanguage

        switch mode {
        case .rawCaptions:
            chatPrompt = LocalChatPrompt(system: "", user: text)
        case .cleanedCaptions:
            chatPrompt = LocalChatPrompt(
                system: """
                You clean live subtitles for immediate on-screen display.
                Add punctuation and casing, remove obvious ASR artifacts, and preserve the speaker's meaning.
                Keep the result short enough for one or two subtitle lines.
                Do not summarize, expand, explain, add speaker labels, or mention these instructions.
                Return only the cleaned subtitle text.
                """,
                user: """
                Clean this live subtitle:
                \(text)
                """
            )
        case .translatedSubtitles:
            chatPrompt = LocalChatPrompt(
                system: """
                You translate live subtitles for immediate on-screen display.
                Translate into \(language).
                Preserve names, product names, numbers, and technical terms when translation would make them less clear.
                Keep the result short enough for one or two subtitle lines.
                Do not summarize, expand, explain, add speaker labels, or mention these instructions.
                Return only the translated subtitle text.
                """,
                user: """
                Translate this live subtitle:
                \(text)
                """
            )
        }
    }
}
