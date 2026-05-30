import AVFoundation
import SwiftUI

struct ShortcutsSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Shortcuts",
                    subtitle: "Review and edit EchoV hotkeys and fixed voice commands."
                )

                ForEach(shortcutGroups) { group in
                    SettingsCard(group.title, subtitle: group.subtitle) {
                        VStack(spacing: 12) {
                            ForEach(Array(group.commands.enumerated()), id: \.element.id) { index, command in
                                ShortcutHotkeyRow(
                                    command: command,
                                    context: .shortcuts,
                                    status: command.status(in: container)
                                )

                                if index < group.commands.count - 1 {
                                    DividerLine()
                                }
                            }
                        }
                    }
                }

                SettingsCard("Assistant Commands", subtitle: "Fixed phrases that Assistant listens for while EchoV is running.") {
                    VStack(spacing: 12) {
                        ForEach(Array(voiceCommands.enumerated()), id: \.element.title) { index, command in
                            VoiceCommandReferenceRow(
                                icon: command.icon,
                                title: command.title,
                                subtitle: command.subtitle,
                                status: voiceCommandStatus
                            )

                            if index < voiceCommands.count - 1 {
                                DividerLine()
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .settingsPageBackground()
        .onAppear {
            container.refreshPermissions()
        }
    }

    private var shortcutGroups: [ShortcutCommandGroup] {
        [
            ShortcutCommandGroup(
                title: "Dictation",
                subtitle: "Start, finish, and stop standard dictation.",
                commands: [.toggle, .pushToTalk, .stop]
            ),
            ShortcutCommandGroup(
                title: "Hands-free",
                subtitle: "Listen locally and record when speech starts.",
                commands: [.voiceGate]
            ),
            ShortcutCommandGroup(
                title: "Assistant",
                subtitle: "Start spoken or text-response requests without saying a wake command.",
                commands: [.voiceModeVoice, .voiceModeText]
            ),
            ShortcutCommandGroup(
                title: "Prime",
                subtitle: "Toggle local transcript cleanup.",
                commands: [.prime]
            ),
            ShortcutCommandGroup(
                title: "Trusted Voice",
                subtitle: "Toggle speaker verification for selected voice workflows.",
                commands: [.voiceGuard]
            )
        ]
    }

    private var voiceCommands: [VoiceCommandReference] {
        [
            VoiceCommandReference(
                icon: "speaker.wave.2.bubble",
                title: "Computer",
                subtitle: "Starts a spoken-answer Assistant request."
            ),
            VoiceCommandReference(
                icon: "text.bubble",
                title: "Computer text",
                subtitle: "Starts a text-response session."
            ),
            VoiceCommandReference(
                icon: "arrowshape.turn.up.right",
                title: "Continue",
                subtitle: "Adds a follow-up to the latest text-response session."
            ),
            VoiceCommandReference(
                icon: "wand.and.sparkles",
                title: "Computer cleanup",
                subtitle: "Rewrites selected text with Prime."
            )
        ]
    }

    private var voiceCommandStatus: ShortcutCommandStatus {
        container.settings.isVoiceModeEnabled
            ? ShortcutCommandStatus(text: "Ready", tone: .success)
            : ShortcutCommandStatus(text: "Off", tone: .neutral)
    }
}

struct ShortcutHotkeyRow: View {
    let command: ShortcutCommand
    var context: ShortcutCommandDisplayContext = .settings
    var status: ShortcutCommandStatus?

    @Environment(AppContainer.self) private var container
    @State private var isRecording = false

    var body: some View {
        SettingsRow(
            icon: command.icon,
            title: command.title(in: context),
            subtitle: command.subtitle(in: context)
        ) {
            ViewThatFits(in: .horizontal) {
                controls

                VStack(alignment: .trailing, spacing: 8) {
                    if let status {
                        StatusBadge(text: status.text, tone: status.tone)
                    }

                    HStack(spacing: 8) {
                        KeyboardShortcutChip(text: command.binding(in: container)?.displayName ?? "Not set")

                        Button("Change") {
                            isRecording = true
                        }

                        Button("Clear") {
                            command.set(nil, in: container)
                        }
                        .disabled(command.binding(in: container) == nil)
                    }
                }
            }
        }
        .sheet(isPresented: $isRecording) {
            HotkeyRecorderSheet(
                title: "Set \(command.recorderTitle)",
                onCancel: {
                    isRecording = false
                },
                onCapture: { binding in
                    command.set(binding, in: container)
                    isRecording = false
                }
            )
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if let status {
                StatusBadge(text: status.text, tone: status.tone)
            }

            KeyboardShortcutChip(text: command.binding(in: container)?.displayName ?? "Not set")

            Button("Change") {
                isRecording = true
            }

            Button("Clear") {
                command.set(nil, in: container)
            }
            .disabled(command.binding(in: container) == nil)
        }
    }
}

enum ShortcutCommand: String, CaseIterable, Identifiable {
    case toggle
    case pushToTalk
    case stop
    case voiceGate
    case voiceModeVoice
    case voiceModeText
    case prime
    case voiceGuard

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .toggle:
            "keyboard.badge.ellipsis"
        case .pushToTalk:
            "mic.badge.plus"
        case .stop:
            "stop.circle"
        case .voiceGate:
            "ear"
        case .voiceModeVoice:
            "speaker.wave.2.bubble"
        case .voiceModeText:
            "text.bubble"
        case .prime:
            "wand.and.sparkles"
        case .voiceGuard:
            "person.wave.2"
        }
    }

    var recorderTitle: String {
        switch self {
        case .toggle:
            "Toggle Dictation"
        case .pushToTalk:
            "Push to Talk"
        case .stop:
            "Stop EchoV"
        case .voiceGate:
            "Hands-free"
        case .voiceModeVoice:
            "Assistant Voice"
        case .voiceModeText:
            "Assistant Text"
        case .prime:
            "Prime"
        case .voiceGuard:
            "Trusted Voice"
        }
    }

    func title(in context: ShortcutCommandDisplayContext) -> String {
        switch (self, context) {
        case (.toggle, .settings):
            "Toggle hotkey"
        case (.toggle, .shortcuts):
            "Toggle Dictation"
        case (.pushToTalk, _):
            "Push to Talk"
        case (.stop, _):
            "Stop EchoV"
        case (.voiceGate, .settings):
            "Hands-free hotkey"
        case (.voiceGate, .shortcuts):
            "Hands-free"
        case (.voiceModeVoice, .settings):
            "Manual spoken activation"
        case (.voiceModeVoice, .shortcuts):
            "Assistant Voice"
        case (.voiceModeText, .settings):
            "Manual text activation"
        case (.voiceModeText, .shortcuts):
            "Assistant Text"
        case (.prime, .settings):
            "Prime hotkey"
        case (.prime, .shortcuts):
            "Prime"
        case (.voiceGuard, .settings):
            "Trusted Voice hotkey"
        case (.voiceGuard, .shortcuts):
            "Trusted Voice"
        }
    }

    func subtitle(in _: ShortcutCommandDisplayContext) -> String {
        switch self {
        case .toggle:
            "Press once to start recording, then again to stop."
        case .pushToTalk:
            "Hold the shortcut to record, then release to transcribe."
        case .stop:
            "Cancel active listening, recording, generation, or speech."
        case .voiceGate:
            "Press once to listen hands-free, then press again to mute."
        case .voiceModeVoice:
            "Start spoken-answer listening without saying Computer."
        case .voiceModeText:
            "Start text-response listening without saying Computer text."
        case .prime:
            "Toggle Prime post-processing on or off."
        case .voiceGuard:
            "Toggle the master Trusted Voice switch. Target selections are preserved."
        }
    }

    @MainActor
    func binding(in container: AppContainer) -> HotkeyBinding? {
        switch self {
        case .toggle:
            container.settings.toggleHotkey
        case .pushToTalk:
            container.settings.pushToTalkHotkey
        case .stop:
            container.settings.stopHotkey
        case .voiceGate:
            container.settings.voiceGateHotkey
        case .voiceModeVoice:
            container.settings.voiceModeActivationHotkey
        case .voiceModeText:
            container.settings.voiceModeTextActivationHotkey
        case .prime:
            container.settings.primeToggleHotkey
        case .voiceGuard:
            container.settings.voiceGateVerifierToggleHotkey
        }
    }

    @MainActor
    func set(_ binding: HotkeyBinding?, in container: AppContainer) {
        switch self {
        case .toggle:
            container.setToggleHotkey(binding)
        case .pushToTalk:
            container.setPushToTalkHotkey(binding)
        case .stop:
            container.setStopHotkey(binding)
        case .voiceGate:
            container.setVoiceGateHotkey(binding)
        case .voiceModeVoice:
            container.setVoiceModeActivationHotkey(binding)
        case .voiceModeText:
            container.setVoiceModeTextActivationHotkey(binding)
        case .prime:
            container.setPrimeToggleHotkey(binding)
        case .voiceGuard:
            container.setVoiceGateVerifierToggleHotkey(binding)
        }
    }

    @MainActor
    func status(in container: AppContainer) -> ShortcutCommandStatus {
        guard binding(in: container) != nil else {
            return ShortcutCommandStatus(text: "Not set", tone: .neutral)
        }

        switch self {
        case .toggle, .pushToTalk, .voiceGate:
            return speechCaptureStatus(in: container, requiresAccessibility: true)
        case .stop:
            return ShortcutCommandStatus(text: "Ready", tone: .success)
        case .voiceModeVoice, .voiceModeText:
            guard container.settings.isVoiceModeEnabled else {
                return ShortcutCommandStatus(text: "Off", tone: .neutral)
            }
            return speechCaptureStatus(in: container, requiresAccessibility: false)
        case .prime:
            guard container.settings.isPostProcessingEnabled else {
                return ShortcutCommandStatus(text: "Off", tone: .neutral)
            }

            guard container.modelStore.selectedLlamaRuntime?.validation.isValid == true,
                  container.modelStore.selectedPostProcessingModel?.validation.isValid == true
            else {
                return ShortcutCommandStatus(text: "Needs model", tone: .warning)
            }

            return ShortcutCommandStatus(text: "Ready", tone: .success)
        case .voiceGuard:
            guard SpeakerVerifierRuntimeLayout.isInstalled() else {
                return ShortcutCommandStatus(text: "Needs verifier", tone: .warning)
            }

            guard container.speakerProfileStore.profile?.modelID == SpeakerVerifierRuntimeLayout.modelID else {
                return ShortcutCommandStatus(text: "Needs profile", tone: .warning)
            }

            return container.settings.isVoiceGuardEnabled
                ? ShortcutCommandStatus(text: "Ready", tone: .success)
                : ShortcutCommandStatus(text: "Off", tone: .neutral)
        }
    }

    @MainActor
    private func speechCaptureStatus(
        in container: AppContainer,
        requiresAccessibility: Bool
    ) -> ShortcutCommandStatus {
        switch container.permissionState.microphoneAuthorizationStatus {
        case .authorized:
            break
        case .denied, .restricted:
            return ShortcutCommandStatus(text: "Needs mic", tone: .danger)
        case .notDetermined:
            return ShortcutCommandStatus(text: "Needs mic", tone: .warning)
        @unknown default:
            return ShortcutCommandStatus(text: "Needs mic", tone: .warning)
        }

        guard container.modelStore.selectedASRModel?.validation.isValid == true else {
            return ShortcutCommandStatus(text: "Needs model", tone: .warning)
        }

        guard !requiresAccessibility || container.permissionState.isAccessibilityTrusted else {
            return ShortcutCommandStatus(text: "Needs access", tone: .warning)
        }

        return ShortcutCommandStatus(text: "Ready", tone: .success)
    }
}

enum ShortcutCommandDisplayContext {
    case settings
    case shortcuts
}

struct ShortcutCommandStatus {
    let text: String
    let tone: StatusBadge.Tone
}

private struct ShortcutCommandGroup: Identifiable {
    let title: String
    let subtitle: String
    let commands: [ShortcutCommand]

    var id: String {
        title
    }
}

private struct VoiceCommandReference: Identifiable {
    let icon: String
    let title: String
    let subtitle: String

    var id: String {
        title
    }
}

private struct VoiceCommandReferenceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: ShortcutCommandStatus

    var body: some View {
        SettingsRow(
            icon: icon,
            title: title,
            subtitle: subtitle
        ) {
            StatusBadge(text: status.text, tone: status.tone)
        }
    }
}
