import Foundation

enum VoiceGateSpeakerMatchStrictness: String, CaseIterable, Identifiable {
    case balanced
    case strict

    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced:
            "Balanced"
        case .strict:
            "Strict"
        }
    }

    var subtitle: String {
        switch self {
        case .balanced:
            "Allows normal mic distance and speaking variation."
        case .strict:
            "Requires a closer voice match before transcribing."
        }
    }

    var minimumSimilarity: Double {
        switch self {
        case .balanced:
            0.35
        case .strict:
            0.50
        }
    }
}
