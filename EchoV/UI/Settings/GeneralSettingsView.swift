import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Dictation",
                    subtitle: "Control how EchoV records, stores, and inserts transcripts."
                )

                SettingsCard("Recording") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "keyboard",
                            title: "Hotkey",
                            subtitle: "Global shortcut for starting and stopping dictation."
                        ) {
                            KeyboardShortcutChip(text: container.settings.hotkey.displayName)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "text.bubble",
                            title: "Store transcript history",
                            subtitle: "Keep transcripts locally on this Mac."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).isHistoryEnabled)
                                .labelsHidden()
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "trash",
                            title: "Delete temporary audio",
                            subtitle: "Remove captured audio after transcription completes."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).shouldDeleteTemporaryAudio)
                                .labelsHidden()
                        }
                    }
                }

                SettingsCard("Permissions", subtitle: "EchoV needs microphone access to listen and accessibility access to paste into other apps.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "mic.fill",
                            title: "Microphone",
                            subtitle: microphoneHelpText
                        ) {
                            HStack(spacing: 8) {
                                StatusBadge(text: microphoneStatus.text, tone: microphoneStatus.tone)
                                Button("Request") {
                                    requestMicrophoneAccess()
                                }
                                .disabled(container.microphonePermission.authorizationStatus() == .authorized)
                            }
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "cursorarrow.motionlines",
                            title: "Accessibility",
                            subtitle: "Allows EchoV to paste the transcript into the active app."
                        ) {
                            HStack(spacing: 8) {
                                StatusBadge(text: accessibilityStatus.text, tone: accessibilityStatus.tone)
                                Button("Open") {
                                    container.accessibilityPermission.promptForAccess()
                                }
                                .disabled(container.accessibilityPermission.isTrusted())
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

    private var microphoneHelpText: String {
        switch container.microphonePermission.authorizationStatus() {
        case .authorized:
            "Ready to capture dictation audio."
        case .denied, .restricted:
            "Enable access in System Settings to record."
        case .notDetermined:
            "Permission has not been requested yet."
        @unknown default:
            "Permission status is unavailable."
        }
    }

    private var accessibilityStatus: (text: String, tone: StatusBadge.Tone) {
        container.accessibilityPermission.isTrusted()
            ? ("Allowed", .success)
            : ("Needed", .warning)
    }

    private func requestMicrophoneAccess() {
        Task {
            _ = await container.microphonePermission.requestAccess()
        }
    }
}
