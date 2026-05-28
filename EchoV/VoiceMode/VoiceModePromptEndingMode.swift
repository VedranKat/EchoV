import Foundation

enum VoiceModePromptEndingMode: String, CaseIterable, Identifiable, Sendable {
    case fixedPause
    case adaptivePause
    case stopPhrase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixedPause:
            "Fixed"
        case .adaptivePause:
            "Adaptive"
        case .stopPhrase:
            "Stop Phrase"
        }
    }

    var subtitle: String {
        switch self {
        case .fixedPause:
            "Send after the configured silence pause."
        case .adaptivePause:
            "Use a shorter pause after the request is clearly underway."
        case .stopPhrase:
            "Strip a custom final phrase before sending the request."
        }
    }
}

enum VoiceModeAdaptivePausePreset: String, CaseIterable, Identifiable, Sendable {
    case relaxed
    case balanced
    case fast
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed:
            "Relaxed"
        case .balanced:
            "Balanced"
        case .fast:
            "Fast"
        case .custom:
            "Custom"
        }
    }

    var timing: VoiceModeAdaptivePauseTiming? {
        switch self {
        case .relaxed:
            VoiceModeAdaptivePauseTiming(initialPauseSeconds: 1.6, fastPauseSeconds: 0.9, minimumSpeechSeconds: 1.2)
        case .balanced:
            VoiceModeAdaptivePauseTiming(initialPauseSeconds: 1.2, fastPauseSeconds: 0.6, minimumSpeechSeconds: 1.0)
        case .fast:
            VoiceModeAdaptivePauseTiming(initialPauseSeconds: 0.8, fastPauseSeconds: 0.45, minimumSpeechSeconds: 0.8)
        case .custom:
            nil
        }
    }
}

struct VoiceModeAdaptivePauseTiming: Equatable, Sendable {
    let initialPauseSeconds: TimeInterval
    let fastPauseSeconds: TimeInterval
    let minimumSpeechSeconds: TimeInterval
}

struct VoiceModePromptText: Equatable, Sendable {
    let text: String
    let endedByStopPhrase: Bool
}

struct VoiceModePromptEndingPolicy: Equatable, Sendable {
    let mode: VoiceModePromptEndingMode
    let fixedPauseSeconds: TimeInterval
    let adaptiveFastPauseSeconds: TimeInterval
    let adaptiveMinimumSpeechSeconds: TimeInterval
    let stopPhrase: String

    init(
        mode: VoiceModePromptEndingMode,
        fixedPauseSeconds: TimeInterval,
        adaptiveFastPauseSeconds: TimeInterval,
        adaptiveMinimumSpeechSeconds: TimeInterval,
        stopPhrase: String
    ) {
        self.mode = mode
        self.fixedPauseSeconds = fixedPauseSeconds
        self.adaptiveFastPauseSeconds = adaptiveFastPauseSeconds
        self.adaptiveMinimumSpeechSeconds = adaptiveMinimumSpeechSeconds
        self.stopPhrase = Self.normalizedStopPhrase(stopPhrase)
    }

    init(
        mode: VoiceModePromptEndingMode,
        fixedPauseSeconds: TimeInterval,
        adaptivePausePreset: VoiceModeAdaptivePausePreset,
        customAdaptiveFastPauseSeconds: TimeInterval,
        customAdaptiveMinimumSpeechSeconds: TimeInterval,
        stopPhrase: String
    ) {
        let timing = adaptivePausePreset.timing
        self.init(
            mode: mode,
            fixedPauseSeconds: timing?.initialPauseSeconds ?? fixedPauseSeconds,
            adaptiveFastPauseSeconds: timing?.fastPauseSeconds ?? customAdaptiveFastPauseSeconds,
            adaptiveMinimumSpeechSeconds: timing?.minimumSpeechSeconds ?? customAdaptiveMinimumSpeechSeconds,
            stopPhrase: stopPhrase
        )
    }

    func silenceTimeout(afterSpeechDuration speechDuration: TimeInterval) -> TimeInterval {
        guard mode == .adaptivePause, speechDuration >= adaptiveMinimumSpeechSeconds else {
            return fixedPauseSeconds
        }

        return min(fixedPauseSeconds, adaptiveFastPauseSeconds)
    }

    var captureSilenceTimeout: VoiceGateCaptureSilenceTimeout {
        switch mode {
        case .adaptivePause:
            return .adaptive(
                initialSeconds: fixedPauseSeconds,
                fastSeconds: adaptiveFastPauseSeconds,
                minimumSpeechSeconds: adaptiveMinimumSpeechSeconds
            )
        case .fixedPause, .stopPhrase:
            return .fixed(seconds: fixedPauseSeconds)
        }
    }

    func promptText(from transcript: String) -> VoiceModePromptText {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return VoiceModePromptText(text: "", endedByStopPhrase: false)
        }

        guard mode == .stopPhrase,
              !stopPhrase.isEmpty,
              let range = trailingStopPhraseRange(in: trimmed)
        else {
            return VoiceModePromptText(text: trimmed, endedByStopPhrase: false)
        }

        let promptText = (trimmed as NSString)
            .replacingCharacters(in: range, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return VoiceModePromptText(text: promptText, endedByStopPhrase: true)
    }

    private static func normalizedStopPhrase(_ phrase: String) -> String {
        phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func trailingStopPhraseRange(in text: String) -> NSRange? {
        let words = Self.normalizedStopPhrase(stopPhrase)
            .components(separatedBy: " ")
            .map(NSRegularExpression.escapedPattern(for:))
        guard !words.isEmpty else {
            return nil
        }

        let escapedPhrasePattern = words.joined(separator: #"\s+"#)
        let pattern = #"(?i)(?:^|\s)\b\#(escapedPhrasePattern)\b[\s.!?,;:]*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.firstMatch(in: text, range: range)?.range
    }
}
