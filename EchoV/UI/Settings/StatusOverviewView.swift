import SwiftUI

struct StatusOverviewView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "EchoV",
                    subtitle: "Local dictation status, model readiness, and permissions."
                )

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

                        Button(action: toggleRecording) {
                            Label(actionTitle, systemImage: actionIcon)
                                .frame(minWidth: 132)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
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
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var statusTitle: String {
        switch container.appState.state {
        case .idle:
            "Ready"
        case .recording:
            "Recording"
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

    private var statusDetail: String {
        if let detail = container.appState.lastDetail, !detail.isEmpty {
            return detail
        }

        return switch container.appState.state {
        case .idle:
            "Use the hotkey or start recording from here."
        case .recording:
            "Speak naturally. Stop recording when you are done."
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
        case .recording:
            "record.circle"
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
        case .recording, .transcribing, .cleaning, .inserting:
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
        case .recording:
            "Live"
        case .transcribing, .cleaning, .inserting:
            "Working"
        case .completed:
            "Done"
        case .failed:
            "Needs attention"
        case .cancelled:
            "Stopped"
        }
    }

    private var actionTitle: String {
        if case .recording = container.appState.state {
            return "Stop Recording"
        }
        return "Start Recording"
    }

    private var actionIcon: String {
        if case .recording = container.appState.state {
            return "stop.fill"
        }
        return "mic.fill"
    }

    private var microphoneStatus: (text: String, tone: StatusBadge.Tone) {
        switch container.microphonePermission.authorizationStatus() {
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
        container.accessibilityPermission.isTrusted()
            ? ("Allowed", .success)
            : ("Needed", .warning)
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

    private func toggleRecording() {
        Task {
            await container.pipeline.toggleRecording()
        }
    }
}
