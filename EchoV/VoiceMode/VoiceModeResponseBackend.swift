import Foundation

enum VoiceModeResponseBackend: String, CaseIterable, Identifiable, Sendable {
    case localLlama
    case openAICompatibleCloud

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localLlama:
            "Local llama"
        case .openAICompatibleCloud:
            "OpenAI-compatible cloud"
        }
    }

    var subtitle: String {
        switch self {
        case .localLlama:
            "Use the selected local text model through llama-server."
        case .openAICompatibleCloud:
            "Send Voice Mode requests to a configured chat completions endpoint."
        }
    }
}
