import Foundation

enum PostProcessingLevel: String, CaseIterable, Identifiable, Sendable {
    case minimal
    case balanced
    case concise

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .minimal:
            "Minimal"
        case .balanced:
            "Balanced"
        case .concise:
            "Concise"
        }
    }

    var subtitle: String {
        switch self {
        case .minimal:
            "Only fix obvious artifacts and nonsensical fragments."
        case .balanced:
            "Clean fillers, repeats, and false starts while preserving intent."
        case .concise:
            "Reduce noise aggressively and produce short, direct text."
        }
    }
}
