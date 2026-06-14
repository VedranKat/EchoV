import AppKit
import Foundation

enum AssistantConfirmationSoundStyle: String, CaseIterable, Identifiable, Sendable {
    case starship
    case computer
    case terminal
    case modern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starship:
            return "Starship"
        case .computer:
            return "Computer"
        case .terminal:
            return "Terminal"
        case .modern:
            return "Modern"
        }
    }

    var subtitle: String {
        switch self {
        case .starship:
            return "Clean bridge-console chimes."
        case .computer:
            return "Classic sci-fi computer tones."
        case .terminal:
            return "Retro data-terminal blips."
        case .modern:
            return "Soft polished system sounds."
        }
    }

    static func load(from rawValue: String?) -> AssistantConfirmationSoundStyle {
        guard let rawValue, let style = AssistantConfirmationSoundStyle(rawValue: rawValue) else {
            return .starship
        }

        return style
    }
}

enum AssistantConfirmationCue: String, Sendable {
    case voiceReady = "voice-ready"
    case voiceRefresh = "voice-refresh"
    case textReady = "text-ready"
    case actionAccepted = "action-accepted"
    case rejected

    static func cue(
        for command: VoiceModeActivationCommand,
        activeSessionKind: TextResponseSessionKind?
    ) -> AssistantConfirmationCue {
        switch command {
        case .spoken:
            return .voiceReady
        case .refreshSession:
            return .voiceRefresh
        case .textResponse:
            return .textReady
        case .continueTextResponse:
            return activeSessionKind == .text ? .textReady : .voiceReady
        case .cleanUpSelection:
            return .actionAccepted
        }
    }

    var promptStartDelayMilliseconds: Int {
        switch self {
        case .voiceReady:
            return 230
        case .voiceRefresh:
            return 290
        case .textReady:
            return 170
        case .actionAccepted:
            return 130
        case .rejected:
            return 220
        }
    }
}

@MainActor
final class AssistantConfirmationSoundService: NSObject, NSSoundDelegate {
    private var activeSounds: [NSSound] = []

    func play(
        _ cue: AssistantConfirmationCue,
        style: AssistantConfirmationSoundStyle,
        waitsForCue: Bool = true
    ) async {
        guard let sound = sound(for: cue, style: style) else {
            return
        }

        activeSounds.append(sound)
        let didStart = sound.play()
        if !didStart {
            activeSounds.removeAll { $0 === sound }
            return
        }

        if waitsForCue {
            try? await Task.sleep(for: .milliseconds(cue.promptStartDelayMilliseconds))
        }
    }

    private func sound(for cue: AssistantConfirmationCue, style: AssistantConfirmationSoundStyle) -> NSSound? {
        guard let url = Bundle.main.url(
            forResource: cue.rawValue,
            withExtension: "wav",
            subdirectory: "AssistantSounds/\(style.rawValue)"
        ) else {
            return nil
        }

        guard let sound = NSSound(contentsOf: url, byReference: true) else {
            return nil
        }

        sound.delegate = self
        sound.volume = 0.68
        return sound
    }

    nonisolated func sound(_ sound: NSSound, didFinishPlaying finishedPlaying: Bool) {
        Task { @MainActor [weak self] in
            self?.activeSounds.removeAll { $0 === sound }
        }
    }
}
