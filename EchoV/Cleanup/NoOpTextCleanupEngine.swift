import Foundation

struct NoOpTextCleanupEngine: TextCleanupEngine {
    let id = "none"
    let displayName = "No Cleanup"

    func clean(_ transcript: Transcript) async throws -> CleanedText {
        CleanedText(text: transcript.text)
    }
}
