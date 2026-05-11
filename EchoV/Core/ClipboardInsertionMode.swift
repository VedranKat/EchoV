import Foundation

enum ClipboardInsertionMode: String, CaseIterable, Identifiable, Sendable {
    case pasteAndRestorePrevious = "pasteAndRestorePrevious"
    case pasteAndKeepTranscript = "pasteAndKeepTranscript"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .pasteAndRestorePrevious:
            "Paste, then restore previous"
        case .pasteAndKeepTranscript:
            "Paste and keep transcript"
        }
    }

    var subtitle: String {
        switch self {
        case .pasteAndRestorePrevious:
            "Use the clipboard for pasting, then put your previous clipboard back."
        case .pasteAndKeepTranscript:
            "Paste automatically and leave the transcript available to paste again."
        }
    }
}
