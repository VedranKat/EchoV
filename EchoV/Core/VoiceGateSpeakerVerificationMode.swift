import Foundation

enum VoiceGateSpeakerVerificationMode: String, CaseIterable, Identifiable {
    case startOnly
    case continuous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startOnly:
            "Start"
        case .continuous:
            "Continuous"
        }
    }

    var subtitle: String {
        switch self {
        case .startOnly:
            "Verify the first speech segment before transcribing."
        case .continuous:
            "Verify overlapping speech windows before transcribing."
        }
    }
}
