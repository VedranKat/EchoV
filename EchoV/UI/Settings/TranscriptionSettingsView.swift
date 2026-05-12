import SwiftUI

struct TranscriptionSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Model",
                    subtitle: "Manage local transcription and post-processing models."
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

                            SetupHelpButton(
                                title: "Parakeet folder",
                                message: "Select \(ParakeetLocalModelLayout.expectedFolderName), \(ParakeetLocalModelLayout.downloadFolderName), or a parent folder containing either. The folder must include the Core ML bundles and parakeet_vocab.json."
                            )

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

                SettingsCard("Post-processing", subtitle: "Use Gemma 4 E2B locally to clean dictated text after transcription.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "wand.and.sparkles",
                            title: "Prime",
                            subtitle: postProcessingSubtitle
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { container.settings.isPostProcessingEnabled },
                                    set: { container.setPostProcessingEnabled($0) }
                                )
                            )
                            .labelsHidden()
                        }

                        DividerLine()

                        HStack(alignment: .center, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(llamaRuntimeTone.color.opacity(0.15))
                                    .frame(width: 58, height: 58)

                                Image(systemName: "cpu")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(llamaRuntimeTone.color)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(llamaRuntimeTitle)
                                        .font(.title3.weight(.semibold))
                                    StatusBadge(text: llamaRuntimeBadgeText, tone: llamaRuntimeTone)
                                }

                                Text(llamaRuntimeInstallMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Button {
                                installManagedLlamaRuntime()
                            } label: {
                                Label(
                                    container.modelStore.llamaRuntimeInstallState.isInstalling ? "Installing..." : "Download",
                                    systemImage: "arrow.down.circle"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(container.modelStore.llamaRuntimeInstallState.isInstalling)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "terminal",
                            title: "Runtime folder",
                            subtitle: container.modelStore.selectedLlamaRuntime?.displayName ?? "No llama.cpp runtime folder selected."
                        ) {
                            StatusBadge(text: llamaRuntimeValidationBadgeText, tone: llamaRuntimeValidationTone)
                        }

                        DividerLine()

                        HStack {
                            Button {
                                selectLlamaRuntimeFolder()
                            } label: {
                                Label("Select Runtime", systemImage: "folder.badge.plus")
                            }

                            SetupHelpButton(
                                title: "llama.cpp runtime",
                                message: "Select any compatible llama.cpp runtime folder containing executable llama-server. EchoV's managed download uses tested stable \(LlamaRuntimeLayout.version)."
                            )

                            Button {
                                container.clearLlamaRuntimeSelection()
                            } label: {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                            .disabled(container.modelStore.selectedLlamaRuntime == nil)

                            Spacer()
                        }

                        DividerLine()

                        HStack(alignment: .center, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(postProcessingTone.color.opacity(0.15))
                                    .frame(width: 58, height: 58)

                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(postProcessingTone.color)
                            }

                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 8) {
                                    Text(postProcessingTitle)
                                        .font(.title3.weight(.semibold))
                                    StatusBadge(text: postProcessingBadgeText, tone: postProcessingTone)
                                }

                            Text(postProcessingInstallMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Button {
                                installManagedPostProcessingModel()
                            } label: {
                                Label(
                                    container.modelStore.postProcessingInstallState.isInstalling ? "Installing..." : "Download",
                                    systemImage: "arrow.down.circle"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                container.modelStore.postProcessingInstallState.isInstalling
                                    || container.modelStore.selectedLlamaRuntime?.validation.isValid != true
                            )
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "folder",
                            title: "Selected folder",
                            subtitle: container.modelStore.selectedPostProcessingModel?.displayName ?? "No Gemma 4 model folder selected."
                        ) {
                            StatusBadge(text: postProcessingValidationBadgeText, tone: postProcessingValidationTone)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "checkmark.seal",
                            title: "Validation",
                            subtitle: container.modelStore.postProcessingValidation.message
                        ) {
                            EmptyView()
                        }

                        DividerLine()

                        HStack {
                            Button {
                                selectPostProcessingModelFolder()
                            } label: {
                                Label("Select Folder", systemImage: "folder.badge.plus")
                            }

                            SetupHelpButton(
                                title: "Gemma folder",
                                message: "Select \(Gemma4PostProcessingModelLayout.expectedFolderName), \(Gemma4PostProcessingModelLayout.modelID), or a parent folder. The selected folder must contain \(Gemma4PostProcessingModelLayout.ggufFileName) or another .gguf file."
                            )

                            Button {
                                container.clearPostProcessingModelSelection()
                            } label: {
                                Label("Clear", systemImage: "xmark.circle")
                            }
                            .disabled(container.modelStore.selectedPostProcessingModel == nil)

                            Spacer()
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

    private var postProcessingSubtitle: String {
        container.settings.isPostProcessingEnabled
            ? "Enabled. EchoV will keep the selected post-processing model ready."
            : "Disabled. EchoV will insert the raw transcript."
    }

    private var postProcessingTitle: String {
        if let model = container.modelStore.selectedPostProcessingModel {
            return model.displayName
        }

        return Gemma4PostProcessingModelLayout.displayName
    }

    private var llamaRuntimeTitle: String {
        if let runtime = container.modelStore.selectedLlamaRuntime {
            return runtime.displayName
        }

        return LlamaRuntimeLayout.displayName
    }

    private var llamaRuntimeInstallMessage: String {
        switch container.modelStore.llamaRuntimeInstallState {
        case .idle:
            "Managed download: ggml-org/llama.cpp / \(LlamaRuntimeLayout.archiveFileName)"
        default:
            container.modelStore.llamaRuntimeInstallState.message
        }
    }

    private var llamaRuntimeBadgeText: String {
        if container.modelStore.selectedLlamaRuntime?.validation.isValid == true {
            return "Ready"
        }

        if container.modelStore.llamaRuntimeInstallState.isInstalling {
            return "Installing"
        }

        if case .failed = container.modelStore.llamaRuntimeInstallState {
            return "Failed"
        }

        return "Setup needed"
    }

    private var llamaRuntimeTone: StatusBadge.Tone {
        if container.modelStore.selectedLlamaRuntime?.validation.isValid == true {
            return .success
        }

        if container.modelStore.llamaRuntimeInstallState.isInstalling {
            return .active
        }

        if case .failed = container.modelStore.llamaRuntimeInstallState {
            return .danger
        }

        return .warning
    }

    private var llamaRuntimeValidationBadgeText: String {
        container.modelStore.llamaRuntimeValidation.isValid ? "Valid" : "Invalid"
    }

    private var llamaRuntimeValidationTone: StatusBadge.Tone {
        container.modelStore.llamaRuntimeValidation.isValid ? .success : .warning
    }

    private var postProcessingInstallMessage: String {
        switch container.modelStore.postProcessingInstallState {
        case .idle:
            "Managed download: \(Gemma4PostProcessingModelLayout.ggufRepositoryID) / \(Gemma4PostProcessingModelLayout.ggufFileName)"
        default:
            container.modelStore.postProcessingInstallState.message
        }
    }

    private var postProcessingBadgeText: String {
        if !container.settings.isPostProcessingEnabled {
            return "Off"
        }

        if container.modelStore.selectedLlamaRuntime?.validation.isValid != true {
            return "Runtime needed"
        }

        if container.modelStore.selectedPostProcessingModel?.validation.isValid == true {
            return "Ready"
        }

        if case .failed = container.modelStore.postProcessingInstallState {
            return "Failed"
        }

        return "Setup needed"
    }

    private var postProcessingTone: StatusBadge.Tone {
        if !container.settings.isPostProcessingEnabled {
            return .neutral
        }

        if container.modelStore.selectedLlamaRuntime?.validation.isValid != true {
            return .warning
        }

        if container.modelStore.selectedPostProcessingModel?.validation.isValid == true {
            return .success
        }

        if case .failed = container.modelStore.postProcessingInstallState {
            return .danger
        }

        return .warning
    }

    private var postProcessingValidationBadgeText: String {
        container.modelStore.postProcessingValidation.isValid ? "Valid" : "Invalid"
    }

    private var postProcessingValidationTone: StatusBadge.Tone {
        container.modelStore.postProcessingValidation.isValid ? .success : .warning
    }

    private func installManagedModel() {
        Task {
            await container.installManagedASRModel()
        }
    }

    private func installManagedPostProcessingModel() {
        Task {
            await container.installManagedPostProcessingModel()
        }
    }

    private func installManagedLlamaRuntime() {
        Task {
            await container.installManagedLlamaRuntime()
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

    private func selectPostProcessingModelFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await container.selectPostProcessingModel(at: url)
            }
        }
    }

    private func selectLlamaRuntimeFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await container.selectLlamaRuntime(at: url)
            }
        }
    }
}
