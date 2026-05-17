import Foundation

enum VoiceGateSilenceTimeout: String, CaseIterable, Identifiable {
    case short
    case balanced
    case long
    case patient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .short:
            "0.6s"
        case .balanced:
            "0.9s"
        case .long:
            "1.2s"
        case .patient:
            "1.8s"
        }
    }

    var seconds: TimeInterval {
        switch self {
        case .short:
            0.6
        case .balanced:
            0.9
        case .long:
            1.2
        case .patient:
            1.8
        }
    }

    var subtitle: String {
        "Transcribe after \(title) of silence."
    }
}
