import SwiftUI

struct TranscriptionSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var newVocabularyTerm = ""
    @State private var newVocabularyAliases = ""
    @State private var newVocabularyAggressiveness = PrimeVocabularyAggressiveness.conservative

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Model",
                    subtitle: "Manage local transcription and post-processing models."
                )

                SettingsCard("Local Transcription", subtitle: "Use Parakeet locally for dictation. Choose \(ParakeetLocalModelLayout.downloadFolderName), \(ParakeetLocalModelLayout.expectedFolderName), or their parent folder.") {
                    VStack(spacing: 12) {
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

                        DividerLine()

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

                        ShortcutHotkeyRow(command: .prime)

                        DividerLine()

                        SettingsRow(
                            icon: "slider.horizontal.3",
                            title: "Cleanup level",
                            subtitle: container.settings.postProcessingLevel.subtitle
                        ) {
                            Picker("", selection: Bindable(container.settings).postProcessingLevel) {
                                ForEach(PostProcessingLevel.allCases) { level in
                                    Text(level.title).tag(level)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 260)
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

                SettingsCard("Prime Context", subtitle: "App-aware formatting and custom vocabulary are applied only when Prime cleans text.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "app.badge",
                            title: "App-aware formatting",
                            subtitle: "Prime uses the frontmost app to choose a conservative formatting style for chat, email, code, terminal, notes, or general text."
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { container.settings.isPrimeAppAwareFormattingEnabled },
                                    set: { container.setPrimeAppAwareFormattingEnabled($0) }
                                )
                            )
                            .labelsHidden()
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "text.book.closed",
                            title: "Custom vocabulary",
                            subtitle: vocabularySubtitle
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { container.settings.isPrimeCustomVocabularyEnabled },
                                    set: { container.setPrimeCustomVocabularyEnabled($0) }
                                )
                            )
                            .labelsHidden()
                        }

                        if container.settings.isPrimeCustomVocabularyEnabled {
                            DividerLine()

                            vocabularyEditor
                        }
                    }
                }
            }
            .padding(24)
        }
        .settingsPageBackground()
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

    private var vocabularySubtitle: String {
        "\(container.settings.primeVocabularyEntries.count) of \(PrimeVocabularyEntry.maximumEntries) terms configured. Terms and aliases are capped at \(PrimeVocabularyEntry.maximumTermLength) characters."
    }

    private var vocabularyEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                TextField("Term", text: $newVocabularyTerm)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 150)

                TextField("Aliases, comma separated", text: $newVocabularyAliases)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 220)

                Picker("", selection: $newVocabularyAggressiveness) {
                    ForEach(PrimeVocabularyAggressiveness.allCases) { aggressiveness in
                        Text(aggressiveness.title).tag(aggressiveness)
                    }
                }
                .labelsHidden()
                .frame(width: 150)

                Button {
                    addVocabularyEntry()
                } label: {
                    Label("Add", systemImage: "plus.circle")
                }
                .disabled(vocabularyAddValidationFailure != nil)
            }

            if shouldShowVocabularyValidation, let failure = vocabularyAddValidationFailure {
                Text(failure.message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if container.settings.primeVocabularyEntries.isEmpty {
                Text("No custom vocabulary terms yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(container.settings.primeVocabularyEntries) { entry in
                        PrimeVocabularyEntryRow(entry: entry)
                    }
                }
            }
        }
    }

    private var vocabularyAddValidationFailure: PrimeVocabularyValidationFailure? {
        PrimeVocabularyEntry.validationFailure(
            term: newVocabularyTerm,
            aliasCandidates: PrimeVocabularyEntry.aliasCandidates(fromCommaSeparatedText: newVocabularyAliases),
            existingEntries: container.settings.primeVocabularyEntries
        )
    }

    private var shouldShowVocabularyValidation: Bool {
        container.settings.primeVocabularyEntries.count >= PrimeVocabularyEntry.maximumEntries
            || !newVocabularyTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !newVocabularyAliases.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var llamaRuntimeTitle: String {
        if let runtime = container.modelStore.selectedLlamaRuntime {
            return runtime.displayName
        }

        return LlamaRuntimeLayout.displayName
    }

    private var llamaRuntimeInstallMessage: String {
        if !container.settings.isPostProcessingEnabled {
            return "Prime is off. llama-server will stay stopped."
        }

        return switch container.modelStore.llamaRuntimeInstallState {
        case .idle:
            "Managed download: ggml-org/llama.cpp / \(LlamaRuntimeLayout.archiveFileName)"
        default:
            container.modelStore.llamaRuntimeInstallState.message
        }
    }

    private var llamaRuntimeBadgeText: String {
        if !container.settings.isPostProcessingEnabled {
            return "Off"
        }

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
        if !container.settings.isPostProcessingEnabled {
            return .neutral
        }

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

    private func addVocabularyEntry() {
        let aliasCandidates = PrimeVocabularyEntry.aliasCandidates(fromCommaSeparatedText: newVocabularyAliases)
        guard PrimeVocabularyEntry.validationFailure(
            term: newVocabularyTerm,
            aliasCandidates: aliasCandidates,
            existingEntries: container.settings.primeVocabularyEntries
        ) == nil else {
            return
        }

        let aliases = PrimeVocabularyEntry.normalizedAliases(aliasCandidates)
        guard container.addPrimeVocabularyEntry(
            term: newVocabularyTerm,
            aliases: aliases,
            aggressiveness: newVocabularyAggressiveness
        ) else {
            return
        }

        newVocabularyTerm = ""
        newVocabularyAliases = ""
        newVocabularyAggressiveness = .conservative
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

private struct PrimeVocabularyEntryRow: View {
    @Environment(AppContainer.self) private var container
    let entry: PrimeVocabularyEntry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.term)
                        .font(.body.weight(.medium))

                    if entry.isRiskyShortTerm {
                        StatusBadge(text: "Risky", tone: .warning)
                    }
                }

                Text(aliasesText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Picker("", selection: Binding(
                get: { entry.aggressiveness },
                set: { container.setPrimeVocabularyEntryAggressiveness(id: entry.id, aggressiveness: $0) }
            )) {
                ForEach(PrimeVocabularyAggressiveness.allCases) { aggressiveness in
                    Text(aggressiveness.title).tag(aggressiveness)
                }
            }
            .labelsHidden()
            .frame(width: 150)

            Toggle("", isOn: Binding(
                get: { entry.isEnabled },
                set: { container.setPrimeVocabularyEntryEnabled(id: entry.id, isEnabled: $0) }
            ))
            .labelsHidden()

            Button(role: .destructive) {
                container.removePrimeVocabularyEntry(id: entry.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 5)
    }

    private var aliasesText: String {
        if entry.aliases.isEmpty {
            return "No aliases. Prime will use this as a contextual spelling hint."
        }

        return "Aliases: \(entry.aliases.joined(separator: ", "))"
    }
}
