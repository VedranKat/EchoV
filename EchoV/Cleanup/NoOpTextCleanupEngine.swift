import Foundation

struct NoOpTextCleanupEngine: TextCleanupEngine {
    let id = "none"
    let displayName = "No Cleanup"

    func clean(_ transcript: Transcript, level: PostProcessingLevel) async throws -> CleanedText {
        CleanedText(text: transcript.text)
    }
}
