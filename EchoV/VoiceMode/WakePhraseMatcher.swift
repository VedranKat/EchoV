import Foundation

enum VoiceModeActivationCommand: Equatable, Sendable {
    case spoken
    case textResponse
    case continueTextResponse
    case cleanUpSelection

    var phrase: String {
        switch self {
        case .spoken:
            return "computer"
        case .textResponse:
            return "slate"
        case .continueTextResponse:
            return "continue"
        case .cleanUpSelection:
            return "prime cleanup"
        }
    }

    var displayName: String {
        switch self {
        case .cleanUpSelection:
            return "Prime Cleanup"
        case .spoken, .textResponse, .continueTextResponse:
            return phrase.capitalized
        }
    }

    var delivery: VoiceModeResponseDelivery {
        switch self {
        case .spoken:
            return .spoken
        case .textResponse, .continueTextResponse, .cleanUpSelection:
            return .textResponse
        }
    }
}

enum WakePhraseMatcher {
    static let spokenActivationPhrase = "computer"
    static let textResponseActivationPhrase = "slate"
    static let continueTextResponseActivationPhrase = "continue"
    static let cleanUpSelectionActivationPhrase = ["prime", "cleanup"]
    static let cleanUpSelectionSplitActivationPhrase = ["prime", "clean", "up"]

    static func activationCommand(for text: String) -> VoiceModeActivationCommand? {
        switch normalizedTokens(in: text) {
        case [spokenActivationPhrase]:
            return .spoken
        case [textResponseActivationPhrase]:
            return .textResponse
        case [continueTextResponseActivationPhrase]:
            return .continueTextResponse
        case cleanUpSelectionActivationPhrase,
             cleanUpSelectionSplitActivationPhrase:
            return .cleanUpSelection
        default:
            return nil
        }
    }

    private static func normalizedTokens(in text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let normalizedScalars = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return " "
        }

        return String(normalizedScalars)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
    }
}
