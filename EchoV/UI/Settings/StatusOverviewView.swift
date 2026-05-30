import SwiftUI

struct StatusOverviewView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("EchoV")
                            .font(.largeTitle.weight(.semibold))

                        Text(appVersionLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SettingsTheme.controlFill(for: colorScheme), in: Capsule())
                    }

                    Text("Local dictation status, model readiness, and permissions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SettingsCard {
                    HStack(alignment: .center, spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(statusTone.color.opacity(0.15))
                                .frame(width: 70, height: 70)

                            Image(systemName: statusIcon)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(statusTone.color)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(statusTitle)
                                    .font(.title2.weight(.semibold))
                                StatusBadge(text: statusBadgeText, tone: statusTone)
                            }

                            Text(statusDetail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                }

                if !recentRejectedWakeTranscripts.isEmpty {
                    SettingsCard("Ignored Assistant Commands", subtitle: "Recent wake phrases that EchoV did not treat as commands.") {
                        VStack(spacing: 10) {
                            ForEach(Array(recentRejectedWakeTranscripts.enumerated()), id: \.element.id) { index, transcript in
                                rejectedWakeTranscriptRow(transcript)

                                if index < recentRejectedWakeTranscripts.count - 1 {
                                    DividerLine()
                                }
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    SettingsCard("Permissions", subtitle: "Required access for hands-free insertion.") {
                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "mic.fill",
                                title: "Microphone",
                                subtitle: "Captures your dictation audio."
                            ) {
                                StatusBadge(text: microphoneStatus.text, tone: microphoneStatus.tone)
                            }

                            DividerLine()

                            SettingsRow(
                                icon: "cursorarrow.motionlines",
                                title: "Accessibility",
                                subtitle: "Pastes transcripts into the active app."
                            ) {
                                StatusBadge(text: accessibilityStatus.text, tone: accessibilityStatus.tone)
                            }

                            DividerLine()

                            SettingsRow(
                                icon: "power.circle.fill",
                                title: "Start at login",
                                subtitle: startupHelpText
                            ) {
                                StatusBadge(text: startupStatus.text, tone: startupStatus.tone)
                            }
                        }
                    }

                    SettingsCard("Model", subtitle: "Local transcription engine readiness.") {
                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "waveform.badge.magnifyingglass",
                                title: "Selected model",
                                subtitle: container.modelStore.selectedASRModel?.displayName ?? "No model selected"
                            ) {
                                StatusBadge(text: modelSelectionText, tone: modelSelectionTone)
                            }

                            DividerLine()

                            SettingsRow(
                                icon: "wand.and.sparkles",
                                title: "Post-processing",
                                subtitle: postProcessingSubtitle
                            ) {
                                StatusBadge(text: postProcessingText, tone: postProcessingTone)
                            }
                        }
                    }
                }

                if let error = container.appState.lastError {
                    SettingsCard("Latest Error") {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(error.userMessage, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .font(.headline)

                            if let details = error.technicalDetails, !details.isEmpty {
                                Text(details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
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

    private func rejectedWakeTranscriptRow(_ transcript: VoiceModeRejectedWakeTranscript) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: rejectedWakeIcon(for: transcript.reason))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(rejectedWakeTitle(for: transcript))
                    .font(.body)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .textSelection(.enabled)

                Text(rejectedWakeSubtitle(for: transcript.reason))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(transcript.createdAt, style: .time)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 36)
    }

    private var recentRejectedWakeTranscripts: [VoiceModeRejectedWakeTranscript] {
        Array(container.appState.rejectedWakeTranscripts.prefix(5))
    }

    private func rejectedWakeTitle(for transcript: VoiceModeRejectedWakeTranscript) -> String {
        let text = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return "Wake phrase was too long"
        }

        return text
    }

    private func rejectedWakeSubtitle(for reason: VoiceModeRejectedWakeTranscript.Reason) -> String {
        switch reason {
        case .notExactActivationCommand:
            return "Commands must be exactly Computer, Computer text, Continue, or Computer cleanup."
        case .durationExceeded:
            return "Wake command audio exceeded the short command window."
        }
    }

    private func rejectedWakeIcon(for reason: VoiceModeRejectedWakeTranscript.Reason) -> String {
        switch reason {
        case .notExactActivationCommand:
            return "quote.bubble"
        case .durationExceeded:
            return "timer"
        }
    }

    private var statusTitle: String {
        switch container.appState.state {
        case .idle:
            "Ready"
        case .listening:
            "Listening"
        case .recording:
            "Recording"
        case .voiceGateRecording:
            "Recording Speech"
        case .voiceModeWakeListening:
            "Assistant"
        case .voiceModeCheckingWakePhrase:
            "Checking Phrase"
        case .voiceModePromptListening:
            "Assistant"
        case .voiceModePromptRecording:
            "Recording Request"
        case .voiceModeThinking:
            "Thinking"
        case .voiceModeSpeaking:
            "Speaking"
        case .transcribing:
            "Transcribing"
        case .cleaning:
            "Cleaning Transcript"
        case .inserting:
            "Inserting"
        case .completed:
            "Completed"
        case .failed:
            "Failed"
        case .cancelled:
            "Cancelled"
        }
    }

    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "v\(version ?? "0.1.0")"
    }

    private var statusDetail: String {
        if let detail = container.appState.lastDetail, !detail.isEmpty {
            return detail
        }

        return switch container.appState.state {
        case .idle:
            "Use the global hotkey while focused in the app where you want the transcript inserted."
        case .listening:
            "Hands-free is armed. Speak when ready, or press the Hands-free hotkey again to mute."
        case .recording:
            "Speak naturally. Stop recording when you are done."
        case .voiceGateRecording:
            "Speech detected. EchoV will transcribe after the configured silence timeout."
        case .voiceModeWakeListening:
            "Assistant is listening for Computer, Computer text, Continue, or Computer cleanup."
        case .voiceModeCheckingWakePhrase:
            "Checking whether the last phrase was Computer, Computer text, Continue, or Computer cleanup."
        case .voiceModePromptListening:
            "Activation command detected. Say your request."
        case .voiceModePromptRecording:
            "Listening for the end of your request."
        case .voiceModeThinking:
            "Generating a local response."
        case .voiceModeSpeaking:
            "Speaking the local response."
        case .transcribing(let status):
            status
        case .cleaning:
            "Preparing the transcript for insertion."
        case .inserting:
            "Sending text to the active application."
        case .completed(let transcript):
            "\(transcript.text.count) characters transcribed."
        case .failed(let error):
            error.userMessage
        case .cancelled:
            "The last dictation was cancelled."
        }
    }

    private var statusIcon: String {
        switch container.appState.state {
        case .idle:
            "checkmark"
        case .listening:
            "ear"
        case .recording:
            "record.circle"
        case .voiceGateRecording:
            "waveform.circle"
        case .voiceModeWakeListening:
            "speaker.wave.2.bubble"
        case .voiceModeCheckingWakePhrase:
            "text.magnifyingglass"
        case .voiceModePromptListening:
            "captions.bubble"
        case .voiceModePromptRecording:
            "waveform.circle"
        case .voiceModeThinking:
            "cpu"
        case .voiceModeSpeaking:
            "speaker.wave.2"
        case .transcribing, .cleaning:
            "waveform"
        case .inserting:
            "arrow.down.doc"
        case .completed:
            "checkmark.circle"
        case .failed:
            "exclamationmark.triangle"
        case .cancelled:
            "xmark.circle"
        }
    }

    private var statusTone: StatusBadge.Tone {
        switch container.appState.state {
        case .idle, .completed:
            .success
        case .listening,
             .recording,
             .voiceGateRecording,
             .voiceModeWakeListening,
             .voiceModeCheckingWakePhrase,
             .voiceModePromptListening,
             .voiceModePromptRecording,
             .voiceModeThinking,
             .voiceModeSpeaking,
             .transcribing,
             .cleaning,
             .inserting:
            .active
        case .failed:
            .danger
        case .cancelled:
            .warning
        }
    }

    private var statusBadgeText: String {
        switch container.appState.state {
        case .idle:
            "Ready"
        case .listening:
            "Armed"
        case .voiceModeWakeListening, .voiceModePromptListening:
            "Listening"
        case .recording, .voiceGateRecording, .voiceModePromptRecording:
            "Live"
        case .voiceModeCheckingWakePhrase, .voiceModeThinking, .voiceModeSpeaking, .transcribing, .cleaning, .inserting:
            "Working"
        case .completed:
            "Done"
        case .failed:
            "Needs attention"
        case .cancelled:
            "Stopped"
        }
    }

    private var microphoneStatus: (text: String, tone: StatusBadge.Tone) {
        switch container.permissionState.microphoneAuthorizationStatus {
        case .authorized:
            ("Allowed", .success)
        case .denied, .restricted:
            ("Denied", .danger)
        case .notDetermined:
            ("Not requested", .warning)
        @unknown default:
            ("Unknown", .warning)
        }
    }

    private var accessibilityStatus: (text: String, tone: StatusBadge.Tone) {
        container.permissionState.isAccessibilityTrusted
            ? ("Allowed", .success)
            : ("Needed", .warning)
    }

    private var startupStatus: (text: String, tone: StatusBadge.Tone) {
        switch container.permissionState.startupStatus {
        case .enabled:
            ("Enabled", .success)
        case .notRegistered:
            ("Off", .warning)
        case .requiresApproval:
            ("Needs approval", .warning)
        case .unavailable:
            ("Unavailable", .danger)
        }
    }

    private var startupHelpText: String {
        switch container.permissionState.startupStatus {
        case .enabled(.serviceManagement):
            "Opens automatically when you log in."
        case .enabled(.launchAgent):
            "Opens at login using a local LaunchAgent."
        case .notRegistered:
            "Does not open automatically after login."
        case .requiresApproval:
            "Approve it in System Settings > General > Login Items."
        case .unavailable:
            "Startup status is unavailable."
        }
    }

    private var modelSelectionText: String {
        if container.modelStore.selectedASRModel?.validation.isValid == true {
            return "Ready"
        }

        if container.modelStore.installState.isInstalling {
            return "Installing"
        }

        return "Missing"
    }

    private var modelSelectionTone: StatusBadge.Tone {
        if container.modelStore.selectedASRModel?.validation.isValid == true {
            return .success
        }

        if container.modelStore.installState.isInstalling {
            return .active
        }

        return .warning
    }

    private var postProcessingSubtitle: String {
        guard container.settings.isPostProcessingEnabled else {
            return "Disabled. EchoV will insert the raw transcript."
        }

        return container.modelStore.selectedPostProcessingModel?.displayName ?? "No post-processing model selected"
    }

    private var postProcessingText: String {
        guard container.settings.isPostProcessingEnabled else {
            return "Off"
        }

        if container.modelStore.selectedLlamaRuntime?.validation.isValid != true {
            return "Runtime needed"
        }

        if container.modelStore.selectedPostProcessingModel?.validation.isValid == true {
            return "Ready"
        }

        if container.modelStore.postProcessingInstallState.isInstalling {
            return "Installing"
        }

        if case .failed = container.modelStore.postProcessingInstallState {
            return "Failed"
        }

        return "Setup needed"
    }

    private var postProcessingTone: StatusBadge.Tone {
        guard container.settings.isPostProcessingEnabled else {
            return .neutral
        }

        if container.modelStore.selectedLlamaRuntime?.validation.isValid != true {
            return .warning
        }

        if container.modelStore.selectedPostProcessingModel?.validation.isValid == true {
            return .success
        }

        if container.modelStore.postProcessingInstallState.isInstalling {
            return .active
        }

        if case .failed = container.modelStore.postProcessingInstallState {
            return .danger
        }

        return .warning
    }
}
