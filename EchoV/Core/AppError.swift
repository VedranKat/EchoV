import Foundation

enum AppError: LocalizedError, Equatable {
    case microphonePermissionDenied
    case accessibilityPermissionDenied
    case startupRegistrationFailed(details: String)
    case hotkeyUnavailable(details: String)
    case modelNotSelected
    case modelPathInvalid(details: String)
    case modelLoadFailed(details: String)
    case recordingTooShort
    case recordingFailed(details: String)
    case transcriptionFailed(details: String)
    case transcriptionTimedOut
    case cleanupModelNotConfigured
    case cleanupFailed(details: String)
    case insertionFailed(details: String)
    case unknown(details: String)

    var errorDescription: String? {
        userMessage
    }

    var userMessage: String {
        switch self {
        case .microphonePermissionDenied:
            "Microphone permission is required to record dictation."
        case .accessibilityPermissionDenied:
            "Accessibility permission is required to paste into other apps."
        case .startupRegistrationFailed:
            "Could not update startup setting."
        case .hotkeyUnavailable:
            "The selected hotkey is unavailable."
        case .modelNotSelected:
            "Select a local Parakeet model before transcribing."
        case .modelPathInvalid:
            "The selected model path is invalid."
        case .modelLoadFailed:
            "The selected model could not be loaded."
        case .recordingTooShort:
            "Recording was too short to transcribe."
        case .recordingFailed:
            "Recording failed."
        case .transcriptionFailed:
            "Transcription failed."
        case .transcriptionTimedOut:
            "Transcription timed out."
        case .cleanupModelNotConfigured:
            "Select a local text cleanup model before using Prime."
        case .cleanupFailed:
            "Prime cleanup failed."
        case .insertionFailed:
            "Paste insertion failed; the transcript was copied to the clipboard."
        case .unknown:
            "Something went wrong."
        }
    }

    var technicalDetails: String? {
        switch self {
        case .startupRegistrationFailed(let details),
             .hotkeyUnavailable(let details),
             .modelPathInvalid(let details),
             .modelLoadFailed(let details),
             .recordingFailed(let details),
             .transcriptionFailed(let details),
             .cleanupFailed(let details),
             .insertionFailed(let details),
             .unknown(let details):
            details
        case .microphonePermissionDenied,
             .accessibilityPermissionDenied,
             .modelNotSelected,
             .recordingTooShort,
             .transcriptionTimedOut,
             .cleanupModelNotConfigured:
            nil
        }
    }
}
