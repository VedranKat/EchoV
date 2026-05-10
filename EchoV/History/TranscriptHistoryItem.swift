import Foundation

struct TranscriptHistoryItem: Codable, Identifiable, Equatable, Sendable {
    static let maximumSnippetLength = 1_000

    let id: UUID
    let snippet: String
    let createdAt: Date
    let duration: TimeInterval?
    let characterCount: Int

    init(transcript: Transcript) {
        id = transcript.id
        snippet = String(transcript.text.prefix(Self.maximumSnippetLength))
        createdAt = transcript.createdAt
        duration = transcript.duration
        characterCount = transcript.text.count
    }
}
