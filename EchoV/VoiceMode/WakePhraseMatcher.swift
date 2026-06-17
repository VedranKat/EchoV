import Foundation

enum VoiceModeActivationCommand: Equatable, Sendable {
    case spoken
    case textResponse
    case continueTextResponse
    case cleanUpSelection
    case editSelection
    case refreshSession

    var phrase: String {
        switch self {
        case .spoken:
            return "computer"
        case .textResponse:
            return "computer text"
        case .continueTextResponse:
            return "continue"
        case .cleanUpSelection:
            return "computer cleanup"
        case .editSelection:
            return "computer edit"
        case .refreshSession:
            return "computer refresh"
        }
    }

    var displayName: String {
        switch self {
        case .cleanUpSelection:
            return "Computer Cleanup"
        case .editSelection:
            return "Computer Edit"
        case .spoken, .textResponse, .continueTextResponse, .refreshSession:
            return phrase.capitalized
        }
    }

    var delivery: VoiceModeResponseDelivery {
        switch self {
        case .spoken, .refreshSession:
            return .spoken
        case .textResponse, .continueTextResponse, .cleanUpSelection, .editSelection:
            return .textResponse
        }
    }
}

enum WakePhraseMatcher {
    static let spokenActivationPhrase = "computer"
    static let textResponseActivationPhrase = ["computer", "text"]
    static let continueTextResponseActivationPhrase = "continue"
    static let cleanUpSelectionActivationPhrase = ["computer", "cleanup"]
    static let cleanUpSelectionSplitActivationPhrase = ["computer", "clean", "up"]
    static let editSelectionActivationPhrase = ["computer", "edit"]
    static let refreshSessionActivationPhrase = ["computer", "refresh"]

    static func activationCommand(for text: String) -> VoiceModeActivationCommand? {
        switch normalizedTokens(in: text) {
        case [spokenActivationPhrase]:
            return .spoken
        case textResponseActivationPhrase:
            return .textResponse
        case [continueTextResponseActivationPhrase]:
            return .continueTextResponse
        case cleanUpSelectionActivationPhrase,
             cleanUpSelectionSplitActivationPhrase:
            return .cleanUpSelection
        case editSelectionActivationPhrase:
            return .editSelection
        case refreshSessionActivationPhrase:
            return .refreshSession
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
