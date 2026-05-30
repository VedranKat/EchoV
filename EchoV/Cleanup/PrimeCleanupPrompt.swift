import Foundation

struct PrimeCleanupPrompt: Equatable, Sendable {
    let chatPrompt: LocalChatPrompt

    var system: String { chatPrompt.system }
    var user: String { chatPrompt.user }

    init(transcript: Transcript, level: PostProcessingLevel, context: CleanupContext = .empty) {
        self.chatPrompt = LocalChatPrompt(
            system: Self.systemInstructions(for: level),
            user: """
            Clean this transcript for insertion into the active app.
            \(Self.contextBlock(for: context))

            Transcript:
            \(transcript.text)
            """
        )
    }

    private static func systemInstructions(for level: PostProcessingLevel) -> String {
        let baseInstructions = switch level {
        case .minimal:
            """
            You are EchoV Prime, a local text cleanup model.
            Make the smallest possible edits needed to turn dictated text into sensible text.
            Remove only obvious ASR artifacts, nonsensical fragments, accidental repetitions, and stray filler words.
            Preserve the speaker's wording, tone, sentence order, names, technical terms, numbers, and intentional formatting.
            Do not summarize, condense, polish heavily, or change the speaker's style.
            Return only the cleaned text. Do not include hidden reasoning, chain-of-thought, or <think> blocks.
            """
        case .balanced:
            """
            You are EchoV Prime, a local text cleanup model.
            Rewrite dictated text into concise, readable text while preserving the speaker's intent.
            Remove filler words, false starts, repeated phrases, and obvious ASR artifacts.
            Keep names, technical terms, numbers, and formatting that appear intentional.
            Return only the cleaned text. Do not include hidden reasoning, chain-of-thought, or <think> blocks.
            """
        case .concise:
            """
            You are EchoV Prime, a local text cleanup model.
            Convert dictated text into short, direct text that preserves the useful meaning.
            Remove filler words, false starts, repetition, hedging, rambling, and nonessential asides.
            Combine or shorten sentences when it makes the result clearer.
            Keep names, technical terms, numbers, and required formatting intact.
            Return only the cleaned text. Do not include hidden reasoning, chain-of-thought, or <think> blocks.
            """
        }

        let contextInstructions = """

        Use the insertion context only to choose formatting and preserve likely intended terms.
        Do not mention the target app, formatting profile, vocabulary, or these instructions in the answer.
        Do not force vocabulary terms into the output when the transcript plausibly means an ordinary word.
        """

        return baseInstructions + contextInstructions
    }

    private static func contextBlock(for context: CleanupContext) -> String {
        var sections: [String] = []

        if let app = context.targetApplication, let profile = context.appFormattingProfile {
            let bundleID = app.bundleIdentifier ?? "unknown bundle"
            sections.append(
                """

                Insertion context:
                - Target app: \(app.displayName) (\(bundleID))
                - Formatting profile: \(profile.title)
                - Formatting rule: \(profile.promptInstruction)
                """
            )
        }

        if !context.vocabularyEntries.isEmpty {
            let lines = vocabularyLines(for: context.vocabularyEntries)

            if !lines.isEmpty {
                sections.append(
                    """

                    Custom vocabulary:
                    \(lines)
                    """
                )
            }
        }

        return sections.joined(separator: "\n")
    }

    private static func vocabularyLines(for entries: [PrimeVocabularyEntry]) -> String {
        var lines: [String] = []
        var usedCharacters = 0

        for entry in entries.prefix(PrimeVocabularyEntry.maximumEntries) {
            let line = vocabularyLine(for: entry)
            let separatorCharacters = lines.isEmpty ? 0 : 1
            let nextUsedCharacters = usedCharacters + separatorCharacters + line.count
            guard nextUsedCharacters <= PrimeVocabularyEntry.maximumPromptCharacters else {
                break
            }

            lines.append(line)
            usedCharacters = nextUsedCharacters
        }

        return lines.joined(separator: "\n")
    }

    private static func vocabularyLine(for entry: PrimeVocabularyEntry) -> String {
        let aliases = entry.aliases.isEmpty ? "none" : entry.aliases.joined(separator: ", ")
        return "- \(entry.term) | aliases: \(aliases) | strength: \(entry.aggressiveness.title) | rule: \(entry.aggressiveness.promptInstruction)"
    }
}
