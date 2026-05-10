import SwiftUI

struct TranscriptionSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Form {
            Section("Local ASR Model") {
                LabeledContent("Selected model", value: container.modelStore.selectedASRModel?.displayName ?? "None")
                LabeledContent("Status", value: container.modelStore.validation.message)
                Text("Choose \(ParakeetLocalModelLayout.expectedFolderName), or the parent folder that contains it. EchoV only loads local model files.")
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
