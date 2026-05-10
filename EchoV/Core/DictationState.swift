import Foundation

enum DictationState: Equatable {
    case idle
    case recording(startedAt: Date)
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
        case .recording:
            "Recording..."
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
