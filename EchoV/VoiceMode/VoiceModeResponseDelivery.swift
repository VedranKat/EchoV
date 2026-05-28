import Foundation

enum VoiceModeResponseDelivery: String, CaseIterable, Identifiable, Sendable {
    case spoken
    case textResponse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spoken:
            "Voice"
        case .textResponse:
            "Text"
        }
    }

    var subtitle: String {
        switch self {
        case .spoken:
            "Speak answers with Kokoro."
        case .textResponse:
            "Send answers as notifications and keep a chat session."
        }
    }
}
