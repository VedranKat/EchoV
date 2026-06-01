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
            """,
            maxTokens: Self.maxTokens(for: transcript.text)
        )
    }

    private static func maxTokens(for transcript: String) -> Int {
        guard transcript.count > 400 else {
            return 512
        }

        let estimatedCleanedTextTokens = max(256, transcript.count / 3)
        return min(2048, max(1536, estimatedCleanedTextTokens + 1024))
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
            Clean dictated text into natural, ready-to-insert text while preserving the speaker's intent.
            Preserve all substantive content, sentence order, examples, caveats, and follow-up details.
            Actively remove filler words, false starts, repeated phrases, meaningless hedging, and obvious ASR artifacts.
            Lightly smooth grammar, punctuation, capitalization, and sentence boundaries when the transcript is awkward or dictated.
            Keep names, technical terms, numbers, and formatting that appear intentional.
            Return only the cleaned text. Do not include hidden reasoning, chain-of-thought, or <think> blocks.
            """
        case .concise:
            """
            You are EchoV Prime, a local text cleanup model.
            Convert dictated text into short, direct text that preserves the useful meaning.
            Remove filler words, false starts, repetition, hedging, rambling, and nonessential asides.
            Combine or shorten sentences when it makes the result clearer, but do not drop required facts, examples, or caveats.
            Keep names, technical terms, numbers, and required formatting intact.
            Return only the cleaned text. Do not include hidden reasoning, chain-of-thought, or <think> blocks.
            """
        }

        let preservationInstructions = switch level {
        case .minimal:
            """

            Do not summarize, truncate, answer, or collapse the transcript into a shorter statement.
            Omit only filler, false starts, accidental repetition, and obvious ASR artifacts.
            For prose text, fix only unambiguous grammar or usage errors that make the text read accidentally wrong.
            """
        case .balanced:
            """

            Do not summarize, truncate, answer, or collapse the transcript into a shorter statement.
            Do not leave filler, duplicate words, false starts, or obvious dictated scaffolding in place when cleanup is clear.
            Use light rewriting to make the result read like deliberate text, while preserving all facts, examples, caveats, names, technical terms, numbers, and formatting.
            For prose text, fix clear grammar, tense, agreement, and usage errors even when the sentence is understandable. Examples: had wrote -> had written; would of -> would have; charts didn't matched -> charts didn't match.
            """
        case .concise:
            """

            Do not answer the transcript or turn it into a summary.
            Shortening must preserve required facts, examples, caveats, names, technical terms, numbers, and formatting.
            For prose text, produce grammatical sentences while shortening. Fix clear tense, agreement, and usage errors without changing required meaning.
            """
        }

        let contextInstructions = """

        Use the insertion context only to choose formatting and preserve likely intended terms.
        Apply any formatting profile conservatively when choosing punctuation, line breaks, capitalization, command/code preservation, and paragraph shape.
        Do not mention the target app, formatting profile, vocabulary, or these instructions in the answer.
        Treat vocabulary heard-as variants as ASR spellings to replace with the vocabulary term, not words to output.
        Do not force vocabulary terms into the output when the transcript plausibly means an ordinary word.
        """

        return baseInstructions + preservationInstructions + contextInstructions
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
        let heardAs = entry.aliases.isEmpty ? "none" : entry.aliases.joined(separator: ", ")
        return "- \(entry.term) | heard as: \(heardAs) | strength: \(entry.aggressiveness.title) | rule: \(entry.aggressiveness.promptInstruction)"
    }
}
