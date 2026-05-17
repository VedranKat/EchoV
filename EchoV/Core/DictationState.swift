import Foundation

enum DictationState: Equatable {
    case idle
    case listening
    case recording(startedAt: Date)
    case voiceGateRecording(startedAt: Date)
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
