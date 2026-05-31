import Foundation
import Observation

@MainActor
@Observable
final class LiveSubtitleStore {
    var isRunning = false
    var statusTitle = "Live Subtitles"
    var statusDetail = "Off"
    var currentText = ""
    var previousText = ""
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
        !currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !previousText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        isFinal: Bool,
        receivedAt: Date = Date()
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        if currentChunkID == chunkID {
            currentText = trimmed
        } else {
            if !currentText.isEmpty {
                previousText = currentText
            }
            currentChunkID = chunkID
            currentText = trimmed
        }

        isCurrentTextFinal = isFinal
        lastUpdatedAt = receivedAt
        lastError = nil
        notifyChanged()
    }

    func clearSubtitles() {
        previousText = ""
        currentText = ""
        currentChunkID = nil
        isCurrentTextFinal = false
        notifyChanged()
    }

    private func notifyChanged() {
        for observer in observers.values {
            observer()
        }
    }
}
