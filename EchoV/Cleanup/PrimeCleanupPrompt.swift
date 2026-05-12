import Foundation

struct PrimeCleanupPrompt: Equatable, Sendable {
    let system: String
    let user: String

    init(transcript: Transcript) {
        self.system = Self.systemInstructions
        self.user = """
        Clean this transcript for insertion into the active app.

        Transcript:
        \(transcript.text)
        """
    }

    private static let systemInstructions = """
    You are EchoV Prime, a local text cleanup model.
    Rewrite dictated text into concise, readable text while preserving the speaker's intent.
    Remove filler words, false starts, repeated phrases, and obvious ASR artifacts.
    Keep names, technical terms, numbers, and formatting that appear intentional.
    Return only the cleaned text.
    """
}
