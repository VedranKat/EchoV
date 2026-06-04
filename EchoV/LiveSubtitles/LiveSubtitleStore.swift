import Foundation
import Observation

struct LiveSubtitleLineID: Hashable, Sendable {
    let chunkID: UUID
    let unitIndex: Int
}

struct VisibleLiveSubtitleLine: Identifiable, Equatable {
    let id: LiveSubtitleLineID
    let chunkID: UUID
    var text: String
    var isFinal: Bool
    var receivedAt: Date
}

@MainActor
@Observable
final class LiveSubtitleStore {
    private static let maximumVisibleSubtitleLines = 3

    var isRunning = false
    var statusTitle = "Live Subtitles"
    var statusDetail = "Off"
    var currentText = ""
    var previousText = ""
    var visibleLines: [VisibleLiveSubtitleLine] = []
    var currentChunkID: UUID?
    var isCurrentTextFinal = false
    var isPostProcessing = false
    var isCatchingUp = false
    var queueDepth = 0
    var liveDelaySeconds: TimeInterval = 0
    var lastError: AppError?
    var lastUpdatedAt: Date?

    @ObservationIgnored private var observers: [UUID: () -> Void] = [:]

    var hasVisibleSubtitle: Bool {
        !visibleLines.isEmpty
    }

    @discardableResult
    func addObserver(_ observer: @escaping () -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    func start(detail: String) {
        isRunning = true
        statusTitle = "Live Subtitles"
        statusDetail = detail
        lastError = nil
        isCatchingUp = false
        notifyChanged()
    }

    func stop(detail: String = "Off") {
        isRunning = false
        statusTitle = "Live Subtitles"
        statusDetail = detail
        isPostProcessing = false
        isCatchingUp = false
        queueDepth = 0
        liveDelaySeconds = 0
        notifyChanged()
    }

    func fail(_ error: AppError) {
        isRunning = false
        lastError = error
        statusTitle = "Live Subtitles"
        statusDetail = error.userMessage
        isPostProcessing = false
        notifyChanged()
    }

    func updateStatus(_ detail: String) {
        statusDetail = detail
        notifyChanged()
    }

    func updateQueueDepth(_ depth: Int) {
        queueDepth = max(0, depth)
        notifyChanged()
    }

    func updateDelay(_ delay: TimeInterval, isCatchingUp: Bool) {
        liveDelaySeconds = max(0, delay)
        self.isCatchingUp = isCatchingUp
        notifyChanged()
    }

    func setPostProcessing(_ isPostProcessing: Bool) {
        self.isPostProcessing = isPostProcessing
        notifyChanged()
    }

    func showSubtitle(
        _ text: String,
        chunkID: UUID,
        lineID: LiveSubtitleLineID? = nil,
        isFinal: Bool,
        receivedAt: Date = Date()
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        let resolvedLineID = lineID ?? LiveSubtitleLineID(chunkID: chunkID, unitIndex: 0)

        if let existingIndex = visibleLines.firstIndex(where: { $0.id == resolvedLineID }),
           visibleLines[existingIndex].isFinal,
           !isFinal {
            return
        }

        if isFinal {
            visibleLines.removeAll {
                $0.chunkID == chunkID && !$0.isFinal && $0.id != resolvedLineID
            }
        }

        if currentChunkID == chunkID {
            currentText = trimmed
        } else {
            previousText = ""
            currentChunkID = chunkID
            currentText = trimmed
        }

        if let existingIndex = visibleLines.firstIndex(where: { $0.id == resolvedLineID }) {
            visibleLines[existingIndex].text = trimmed
            visibleLines[existingIndex].isFinal = isFinal
            visibleLines[existingIndex].receivedAt = receivedAt
        } else {
            visibleLines.append(
                VisibleLiveSubtitleLine(
                    id: resolvedLineID,
                    chunkID: chunkID,
                    text: trimmed,
                    isFinal: isFinal,
                    receivedAt: receivedAt
                )
            )
        }
        trimVisibleLines()
        isCurrentTextFinal = isFinal
        lastUpdatedAt = receivedAt
        lastError = nil
        notifyChanged()
    }

    func clearSubtitles() {
        previousText = ""
        currentText = ""
        visibleLines.removeAll()
        currentChunkID = nil
        isCurrentTextFinal = false
        notifyChanged()
    }

    private func trimVisibleLines() {
        let overflow = visibleLines.count - Self.maximumVisibleSubtitleLines
        if overflow > 0 {
            visibleLines.removeFirst(overflow)
        }
    }

    private func notifyChanged() {
        for observer in observers.values {
            observer()
        }
    }
}
