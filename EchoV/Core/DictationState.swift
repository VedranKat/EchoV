import Foundation

enum DictationState: Equatable {
    case idle
    case listening
    case recording(startedAt: Date)
    case voiceGateRecording(startedAt: Date)
    case voiceModeWakeListening
    case voiceModeCheckingWakePhrase
    case voiceModePromptListening
    case voiceModePromptRecording(startedAt: Date)
    case voiceModeThinking
    case voiceModeSpeaking
    case transcribing(status: String)
    case cleaning
    case inserting
    case completed(Transcript)
    case failed(AppError)
    case cancelled

    var menuTitle: String {
        switch self {
        case .idle:
            "Ready"
        case .listening:
            "Listening for speech..."
        case .recording:
            "Recording..."
        case .voiceGateRecording:
            "Recording speech..."
        case .voiceModeWakeListening:
            "Listening for Computer, Computer refresh, Computer text, Continue, Computer cleanup, or Computer edit..."
        case .voiceModeCheckingWakePhrase:
            "Checking activation phrase..."
        case .voiceModePromptListening:
            "Listening..."
        case .voiceModePromptRecording:
            "Recording request..."
        case .voiceModeThinking:
            "Thinking..."
        case .voiceModeSpeaking:
            "Speaking..."
        case .transcribing(let status):
            status
        case .cleaning:
            "Cleaning..."
        case .inserting:
            "Inserting..."
        case .completed:
            "Completed"
        case .failed(let error):
            "Failed: \(error.userMessage)"
        case .cancelled:
            "Cancelled"
        }
    }
}
