import SwiftUI

struct TranscriptionSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Form {
            Section("Local ASR Model") {
                LabeledContent("Selected model", value: container.modelStore.selectedASRModel?.displayName ?? "None")
                LabeledContent("Status", value: container.modelStore.validation.message)
                Button("Select Local Model Folder...") {
                    selectModelFolder()
                }
                Button("Clear Selection") {
                    container.clearASRModelSelection()
                }
                .disabled(container.modelStore.selectedASRModel == nil)
            }

            Section("Engine") {
                Text("MVP will use FluidAudio with a manually selected local Parakeet model.")
                    .foregroundStyle(.secondary)
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
