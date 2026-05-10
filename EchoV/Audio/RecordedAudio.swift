import Foundation

struct RecordedAudio: Equatable {
    let fileURL: URL
    let startedAt: Date
    let endedAt: Date?

    var duration: TimeInterval {
        guard let endedAt else { return 0 }
        return endedAt.timeIntervalSince(startedAt)
    }
}
