import Foundation

enum LiveSubtitleMode: String, CaseIterable, Identifiable, Sendable {
    case rawCaptions
    case cleanedCaptions
    case translatedSubtitles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rawCaptions:
            "Raw"
        case .cleanedCaptions:
            "Clean"
        case .translatedSubtitles:
            "Translate"
        }
    }

    var subtitle: String {
        switch self {
        case .rawCaptions:
            "Show Parakeet output as soon as each chunk is ready."
        case .cleanedCaptions:
            "Use local llama.cpp to add punctuation and remove obvious ASR artifacts."
        case .translatedSubtitles:
            "Use local llama.cpp to translate Parakeet captions."
        }
    }

    var requiresPostProcessing: Bool {
        self != .rawCaptions
    }
}

enum LiveSubtitleChunkPreset: String, CaseIterable, Identifiable, Sendable {
    case fast
    case balanced
    case accurate
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:
            "Fast"
        case .balanced:
            "Balanced"
        case .accurate:
            "Accurate"
        case .custom:
            "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .fast:
            "Short chunks for lower latency."
        case .balanced:
            "Moderate chunks with natural pause detection."
        case .accurate:
            "Longer chunks for more ASR context."
        case .custom:
            "Use the custom chunk controls below."
        }
    }

    var defaults: LiveSubtitleChunkDefaults {
        switch self {
        case .fast:
            LiveSubtitleChunkDefaults(
                maxChunkSeconds: 3.0,
                silenceTimeoutSeconds: 0.55,
                minimumSpeechSeconds: 0.30,
                preRollSeconds: 0.35,
                overlapSeconds: 0.08,
                sensitivity: .high
            )
        case .balanced, .custom:
            LiveSubtitleChunkDefaults(
                maxChunkSeconds: 4.5,
                silenceTimeoutSeconds: 0.80,
                minimumSpeechSeconds: 0.35,
                preRollSeconds: 0.45,
                overlapSeconds: 0.12,
                sensitivity: .medium
            )
        case .accurate:
            LiveSubtitleChunkDefaults(
                maxChunkSeconds: 6.5,
                silenceTimeoutSeconds: 1.10,
                minimumSpeechSeconds: 0.45,
                preRollSeconds: 0.55,
                overlapSeconds: 0.18,
                sensitivity: .medium
            )
        }
    }
}

struct LiveSubtitleChunkDefaults: Equatable, Sendable {
    let maxChunkSeconds: TimeInterval
    let silenceTimeoutSeconds: TimeInterval
    let minimumSpeechSeconds: TimeInterval
    let preRollSeconds: TimeInterval
    let overlapSeconds: TimeInterval
    let sensitivity: VoiceGateSensitivity
}

struct LiveSubtitleChunkConfiguration: Equatable, Sendable {
    let maxChunkSeconds: TimeInterval
    let silenceTimeoutSeconds: TimeInterval
    let minimumSpeechSeconds: TimeInterval
    let preRollSeconds: TimeInterval
    let overlapSeconds: TimeInterval
    let sensitivity: VoiceGateSensitivity

    init(
        maxChunkSeconds: TimeInterval,
        silenceTimeoutSeconds: TimeInterval,
        minimumSpeechSeconds: TimeInterval,
        preRollSeconds: TimeInterval,
        overlapSeconds: TimeInterval,
        sensitivity: VoiceGateSensitivity
    ) {
        self.maxChunkSeconds = max(1.5, min(maxChunkSeconds, 12.0))
        self.silenceTimeoutSeconds = max(0.25, min(silenceTimeoutSeconds, 2.5))
        self.minimumSpeechSeconds = max(0.15, min(minimumSpeechSeconds, 1.5))
        self.preRollSeconds = max(0.0, min(preRollSeconds, 1.0))
        self.overlapSeconds = max(0.0, min(overlapSeconds, 0.75))
        self.sensitivity = sensitivity
    }
}
