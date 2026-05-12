import SwiftUI

struct StatusOverviewView: View {
    @Environment(AppContainer.self) private var container

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
                            .background(.quaternary, in: Capsule())
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
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            container.refreshPermissions()
        }
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
