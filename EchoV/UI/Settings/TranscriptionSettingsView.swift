import SwiftUI

struct TranscriptionSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Form {
            Section("Install Model") {
                LabeledContent("EchoV model", value: container.modelStore.installState.message)
                Button(container.modelStore.installState.isInstalling ? "Installing..." : "Download and Install Model") {
                    installManagedModel()
                }
                .disabled(container.modelStore.installState.isInstalling)
            }

            Section("Local ASR Model") {
                LabeledContent("Selected model", value: container.modelStore.selectedASRModel?.displayName ?? "None")
                LabeledContent("Status", value: container.modelStore.validation.message)
                Text("Choose \(ParakeetLocalModelLayout.downloadFolderName), \(ParakeetLocalModelLayout.expectedFolderName), or their parent folder. EchoV only loads local model files.")
                    .foregroundStyle(.secondary)
                Button("Select Local Model Folder...") {
                    selectModelFolder()
                }
                Button("Clear Selection") {
                    container.clearASRModelSelection()
                }
                .disabled(container.modelStore.selectedASRModel == nil)
            }
        }
        .padding()
    }

    private func installManagedModel() {
        Task {
            await container.installManagedASRModel()
        }
    }

    private func selectModelFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await container.selectASRModel(at: url)
            }
        }
    }
}
