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
                LabeledContent("Accessibility", value: container.accessibilityPermission.isTrusted() ? "Allowed" : "Needed for paste insertion")
                Button("Request Accessibility Access") {
                    container.accessibilityPermission.promptForAccess()
                }
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

}
