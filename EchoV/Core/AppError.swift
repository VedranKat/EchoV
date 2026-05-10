import Foundation

enum AppError: LocalizedError, Equatable {
    case microphonePermissionDenied
    case accessibilityPermissionDenied
    case hotkeyUnavailable(details: String)
    case modelNotSelected
    case modelPathInvalid(details: String)
    case modelLoadFailed(details: String)
    case recordingTooShort
    case recordingFailed(details: String)
    case transcriptionFailed(details: String)
    case transcriptionTimedOut
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
        case .insertionFailed:
            "Paste insertion failed; the transcript was copied to the clipboard."
        case .unknown:
            "Something went wrong."
        }
    }
}
