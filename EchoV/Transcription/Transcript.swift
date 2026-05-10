import Foundation

struct Transcript: Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let segments: [TranscriptSegment]
    let createdAt: Date
    let duration: TimeInterval?

    init(
        id: UUID = UUID(),
        text: String,
        segments: [TranscriptSegment] = [],
        createdAt: Date = Date(),
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.text = text
        self.segments = segments
        self.createdAt = createdAt
        self.duration = duration
    }
}

struct TranscriptSegment: Identifiable, Equatable, Sendable {
    let id: UUID
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval

    init(id: UUID = UUID(), text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.id = id
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}
