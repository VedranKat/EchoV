import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Form {
            Section("Dictation") {
                LabeledContent("Hotkey", value: container.settings.hotkey.displayName)
                Toggle("Store transcript history locally", isOn: Bindable(container.settings).isHistoryEnabled)
                Toggle("Delete temporary audio after transcription", isOn: Bindable(container.settings).shouldDeleteTemporaryAudio)
            }

            Section("Permissions") {
                LabeledContent("Microphone", value: microphoneStatus)
                Button("Request Microphone Access") {
                    requestMicrophoneAccess()
                }
                .disabled(container.microphonePermission.authorizationStatus() == .authorized)

                LabeledContent("Accessibility", value: accessibilityStatus)
                Button("Request Accessibility Access") {
                    container.accessibilityPermission.promptForAccess()
                }
                .disabled(container.accessibilityPermission.isTrusted())
                Text("Accessibility lets EchoV paste the transcript into the active app. Without it, the transcript stays on the clipboard.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var microphoneStatus: String {
        switch container.microphonePermission.authorizationStatus() {
        case .authorized:
            "Allowed"
        case .denied, .restricted:
            "Denied"
        case .notDetermined:
            "Not requested"
        @unknown default:
            "Unknown"
        }
    }

    private var accessibilityStatus: String {
        container.accessibilityPermission.isTrusted() ? "Allowed" : "Needed for paste insertion"
    }

    private func requestMicrophoneAccess() {
        Task {
            _ = await container.microphonePermission.requestAccess()
        }
    }
}
