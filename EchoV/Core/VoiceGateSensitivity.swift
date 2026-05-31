import Foundation

enum VoiceGateSensitivity: String, CaseIterable, Identifiable, Sendable {
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low:
            "Low"
        case .medium:
            "Medium"
        case .high:
            "High"
        }
    }

    var subtitle: String {
        switch self {
        case .low:
            "Requires a stronger voice signal before recording."
        case .medium:
            "Balances speech pickup with background-noise rejection."
        case .high:
            "Starts recording with quieter speech."
        }
    }

    var minimumSpeechDecibels: Float {
        switch self {
        case .low:
            -34
        case .medium:
            -42
        case .high:
            -50
        }
    }

    var noiseFloorOffsetDecibels: Float {
        switch self {
        case .low:
            18
        case .medium:
            12
        case .high:
            8
        }
    }
}
