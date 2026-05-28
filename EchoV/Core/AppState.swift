import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var state: DictationState = .idle
    var lastError: AppError?
    var lastDetail: String?
    var rejectedWakeTranscripts: [VoiceModeRejectedWakeTranscript] = []
    var voiceModePromptPreview: VoiceModePromptPreviewRequest?
    var onStatusChanged: (() -> Void)?
    @ObservationIgnored private var statusObservers: [UUID: () -> Void] = [:]

    func notifyStatusChanged() {
        onStatusChanged?()
        for observer in statusObservers.values {
            observer()
        }
    }

    @discardableResult
    func addStatusObserver(_ observer: @escaping () -> Void) -> UUID {
        let id = UUID()
        statusObservers[id] = observer
        return id
    }

    func removeStatusObserver(_ id: UUID) {
        statusObservers[id] = nil
    }

    func recordRejectedWakeTranscript(_ transcript: VoiceModeRejectedWakeTranscript) {
        rejectedWakeTranscripts.insert(transcript, at: 0)
        if rejectedWakeTranscripts.count > 20 {
            rejectedWakeTranscripts.removeLast(rejectedWakeTranscripts.count - 20)
        }
    }
}

struct VoiceModePromptPreviewRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let commandTitle: String
    let promptText: String
    let backendTitle: String
    let backendSubtitle: String
    let isCloudBackend: Bool
    let includesSelectionContext: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        commandTitle: String,
        promptText: String,
        backendTitle: String,
        backendSubtitle: String,
        isCloudBackend: Bool,
        includesSelectionContext: Bool,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.commandTitle = commandTitle
        self.promptText = promptText
        self.backendTitle = backendTitle
        self.backendSubtitle = backendSubtitle
        self.isCloudBackend = isCloudBackend
        self.includesSelectionContext = includesSelectionContext
        self.createdAt = createdAt
    }
}

struct VoiceModeRejectedWakeTranscript: Identifiable, Equatable, Sendable {
    enum Reason: String, Equatable, Sendable {
        case notExactActivationCommand
        case durationExceeded
    }

    let id: UUID
    let text: String
    let reason: Reason
    let createdAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        reason: Reason,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.reason = reason
        self.createdAt = createdAt
    }
}
