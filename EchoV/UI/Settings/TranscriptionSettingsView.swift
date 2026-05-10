import SwiftUI

struct TranscriptionSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Model",
                    subtitle: "Manage the local ASR model EchoV uses for private transcription."
                )

                SettingsCard {
                    HStack(alignment: .center, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(modelTone.color.opacity(0.15))
                                .frame(width: 58, height: 58)

                            Image(systemName: "waveform.badge.magnifyingglass")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(modelTone.color)
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text(modelTitle)
                                    .font(.title3.weight(.semibold))
                                StatusBadge(text: modelBadgeText, tone: modelTone)
                            }

                            Text(container.modelStore.installState.message)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Button(container.modelStore.installState.isInstalling ? "Installing..." : "Download") {
                            installManagedModel()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(container.modelStore.installState.isInstalling)
                    }
                }

                SettingsCard("Local Model", subtitle: "Choose \(ParakeetLocalModelLayout.downloadFolderName), \(ParakeetLocalModelLayout.expectedFolderName), or their parent folder.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "folder",
                            title: "Selected folder",
                            subtitle: container.modelStore.selectedASRModel?.displayName ?? "No local model folder selected."
                        ) {
                            StatusBadge(text: validationBadgeText, tone: validationTone)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "checkmark.seal",
                            title: "Validation",
                            subtitle: container.modelStore.validation.message
                        ) {
                            EmptyView()
                        }

                        DividerLine()

                        HStack {
                            Button {
                                selectModelFolder()
                            } label: {
                                Label("Select Folder", systemImage: "folder.badge.plus")
                            }

                            Button {
                                container.clearASRModelSelection()
                            } label: {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                            .disabled(container.modelStore.selectedASRModel == nil)

                            Spacer()
                        }
                    }
                }

                SettingsCard("Performance", subtitle: "Choose which Apple hardware units Core ML may use.") {
                    Picker("Compute mode", selection: computeModeBinding) {
                        ForEach(ASRComputeMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var computeModeBinding: Binding<ASRComputeMode> {
        Binding {
            container.settings.asrComputeMode
        } set: { mode in
            container.updateASRComputeMode(mode)
        }
    }

    private var modelTitle: String {
        if let model = container.modelStore.selectedASRModel {
            return model.displayName
        }

        return "No Model Selected"
    }

    private var modelBadgeText: String {
        if container.modelStore.selectedASRModel?.validation.isValid == true {
            return "Ready"
        }

        if container.modelStore.installState.isInstalling {
            return "Installing"
        }

        if case .failed = container.modelStore.installState {
            return "Failed"
        }

        return "Setup needed"
    }

    private var modelTone: StatusBadge.Tone {
        if container.modelStore.selectedASRModel?.validation.isValid == true {
            return .success
        }

        if container.modelStore.installState.isInstalling {
            return .active
        }

        if case .failed = container.modelStore.installState {
            return .danger
        }

        return .warning
    }

    private var validationBadgeText: String {
        container.modelStore.validation.isValid ? "Valid" : "Invalid"
    }

    private var validationTone: StatusBadge.Tone {
        container.modelStore.validation.isValid ? .success : .warning
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
