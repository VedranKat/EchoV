import SwiftUI

struct VoiceModeSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Assistant",
                    subtitle: "Say Computer for voice, Computer text for fresh text, Continue to follow up, Computer refresh for fresh voice, Computer cleanup to polish selected text, or Computer edit to change selected text."
                )

                SettingsCard("Activation", subtitle: "Keep Assistant explicit and local.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "power",
                            title: "Assistant",
                            subtitle: voiceModeSubtitle
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { container.settings.isVoiceModeEnabled },
                                    set: { container.setVoiceModeEnabled($0) }
                                )
                            )
                            .labelsHidden()
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "text.quote",
                            title: "Voice commands",
                            subtitle: "Computer continues voice, Computer text starts fresh text, Continue follows up, Computer refresh starts fresh voice, and selected-text commands act on the current selection."
                        ) {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 8) {
                                    StatusBadge(text: "Computer", tone: .active)
                                    StatusBadge(text: "Computer refresh", tone: .neutral)
                                    StatusBadge(text: "Computer text", tone: .success)
                                    StatusBadge(text: "Continue", tone: .neutral)
                                    StatusBadge(text: "Computer cleanup", tone: .warning)
                                    StatusBadge(text: "Computer edit", tone: .warning)
                                }

                                VStack(alignment: .trailing, spacing: 6) {
                                    HStack(spacing: 8) {
                                        StatusBadge(text: "Computer", tone: .active)
                                        StatusBadge(text: "Computer refresh", tone: .neutral)
                                    }
                                    HStack(spacing: 8) {
                                        StatusBadge(text: "Computer text", tone: .success)
                                        StatusBadge(text: "Continue", tone: .neutral)
                                    }
                                    HStack(spacing: 8) {
                                        StatusBadge(text: "Computer cleanup", tone: .warning)
                                        StatusBadge(text: "Computer edit", tone: .warning)
                                    }
                                }
                            }
                        }

                        DividerLine()

                        ShortcutHotkeyRow(command: .voiceModeVoice)

                        DividerLine()

                        ShortcutHotkeyRow(command: .voiceModeText)
                    }
                }

                SettingsCard("Response", subtitle: "Control when EchoV sends the prompt and where the answer comes from.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "timer",
                            title: "Prompt ending",
                            subtitle: container.settings.voiceModePromptEndingMode.subtitle
                        ) {
                            Picker(
                                "",
                                selection: Bindable(container.settings).voiceModePromptEndingMode
                            ) {
                                ForEach(VoiceModePromptEndingMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 280)
                        }

                        DividerLine()

                        promptEndingControls

                        DividerLine()

                        SettingsRow(
                            icon: "rectangle.and.pencil.and.ellipsis",
                            title: "Preview before sending",
                            subtitle: "Review, edit, or cancel prompts separately for local and cloud responses."
                        ) {
                            HStack(spacing: 12) {
                                Toggle("Local", isOn: Bindable(container.settings).isLocalVoiceModePromptPreviewEnabled)
                                Toggle("Cloud", isOn: Bindable(container.settings).isCloudVoiceModePromptPreviewEnabled)
                            }
                            .toggleStyle(.switch)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "rectangle.inset.filled.and.person.filled",
                            title: "Status HUD",
                            subtitle: "Show a compact floating Assistant status panel."
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { container.settings.isVoiceModeHUDEnabled },
                                    set: { container.setVoiceModeHUDEnabled($0) }
                                )
                            )
                            .labelsHidden()
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "speaker.wave.2",
                            title: "Confirmation sounds",
                            subtitle: "Play a short cue when an Assistant command is accepted."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).isAssistantConfirmationSoundEnabled)
                                .labelsHidden()
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "waveform",
                            title: "Sound style",
                            subtitle: container.settings.assistantConfirmationSoundStyle.subtitle
                        ) {
                            HStack(spacing: 8) {
                                Picker(
                                    "",
                                    selection: Bindable(container.settings).assistantConfirmationSoundStyle
                                ) {
                                    ForEach(AssistantConfirmationSoundStyle.allCases) { style in
                                        Text(style.title).tag(style)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .frame(width: 170)

                                Button {
                                    Task {
                                        await container.previewAssistantConfirmationSound()
                                    }
                                } label: {
                                    Image(systemName: "play.fill")
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.bordered)
                                .help("Preview")
                            }
                            .disabled(!container.settings.isAssistantConfirmationSoundEnabled)
                        }

                        DividerLine()

                        ResponseBackendSelectionView()
                    }
                }

                if container.settings.voiceModeResponseBackend == .openAICompatibleCloud {
                    SettingsCard("Cloud Response", subtitle: "OpenAI-compatible chat completions provider.") {
                        VStack(spacing: 12) {
                            SettingsRow(
                                icon: "link",
                                title: "Base URL",
                                subtitle: "Example: https://api.example.com/v1"
                            ) {
                                TextField(
                                    "https://api.example.com/v1",
                                    text: Bindable(container.settings).voiceModeCloudBaseURL
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 340)
                            }

                            DividerLine()

                            SettingsRow(
                                icon: "shippingbox",
                                title: "Model",
                                subtitle: "Provider model identifier."
                            ) {
                                TextField(
                                    "model-name",
                                    text: Bindable(container.settings).voiceModeCloudModel
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 340)
                            }

                            DividerLine()

                            SettingsRow(
                                icon: "text.word.spacing",
                                title: "Context window",
                                subtitle: "Required. Set this to the provider model's context length in tokens."
                            ) {
                                CloudContextWindowTextField()
                            }

                            DividerLine()

                            SettingsRow(
                                icon: "key",
                                title: "API key",
                                subtitle: "Stored in the macOS Keychain."
                            ) {
                                SecureField(
                                    "API key",
                                    text: Bindable(container.settings).voiceModeCloudAPIKey
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 340)
                            }
                        }
                    }
                }

                SettingsCard("Text Response", subtitle: "Computer text starts fresh; chat follow-ups can stream.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "dot.radiowaves.left.and.right",
                            title: "Stream chat replies",
                            subtitle: "Show follow-up answers while they generate."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).textResponseStreamsReplies)
                                .labelsHidden()
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "brain",
                            title: "Show reasoning",
                            subtitle: "Only inside chat follow-ups; never in notifications or spoken replies."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).textResponseShowsReasoning)
                                .labelsHidden()
                        }
                    }
                }

                SettingsCard("Kokoro", subtitle: "Computer uses Kokoro CoreML for spoken responses.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "cpu",
                            title: "Engine",
                            subtitle: "CoreML speech synthesis on this Mac."
                        ) {
                            StatusBadge(text: "Kokoro", tone: .success)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "person.wave.2",
                            title: "Voice",
                            subtitle: selectedVoiceSubtitle
                        ) {
                            Picker(
                                "Voice",
                                selection: Bindable(container.settings).voiceModeKokoroVoiceIdentifier
                            ) {
                                ForEach(container.availableSpeechVoices()) { voice in
                                    Text(voice.displayName).tag(voice.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 260)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "gauge.with.dots.needle.bottom.50percent",
                            title: "Speed",
                            subtitle: String(format: "Speak at %.2fx.", container.settings.voiceModeKokoroSpeed)
                        ) {
                            HStack(spacing: 10) {
                                Slider(
                                    value: Bindable(container.settings).voiceModeKokoroSpeed,
                                    in: 0.5...2.0,
                                    step: 0.05
                                )
                                .frame(width: 190)

                                Text(String(format: "%.2fx", container.settings.voiceModeKokoroSpeed))
                                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                                    .frame(width: 52, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .settingsPageBackground()
    }

    private var voiceModeSubtitle: String {
        if container.settings.isVoiceModeEnabled {
            return "Listening for Computer, Computer refresh, Computer text, Continue, Computer cleanup, or Computer edit while EchoV is running."
        }

        return "Assistant starts only when this is enabled."
    }

    @ViewBuilder
    private var promptEndingControls: some View {
        switch container.settings.voiceModePromptEndingMode {
        case .fixedPause:
            SettingsRow(
                icon: "pause.circle",
                title: "Fixed pause",
                subtitle: String(format: "Send after %.1fs of silence.", container.settings.voiceModeResponsePauseSeconds)
            ) {
                secondsSlider(
                    value: Bindable(container.settings).voiceModeResponsePauseSeconds,
                    range: 0.5...3.0,
                    step: 0.1,
                    width: 42,
                    format: "%.1fs"
                )
            }

        case .adaptivePause:
            VStack(spacing: 12) {
                SettingsRow(
                    icon: "slider.horizontal.3",
                    title: "Preset",
                    subtitle: adaptivePresetSubtitle
                ) {
                    Picker(
                        "",
                        selection: Bindable(container.settings).voiceModeAdaptivePausePreset
                    ) {
                        ForEach(VoiceModeAdaptivePausePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                }

                if container.settings.voiceModeAdaptivePausePreset == .custom {
                    DividerLine()

                    SettingsRow(
                        icon: "pause.circle",
                        title: "Initial pause",
                        subtitle: String(format: "Use %.1fs while the request is starting.", container.settings.voiceModeResponsePauseSeconds)
                    ) {
                        secondsSlider(
                            value: Bindable(container.settings).voiceModeResponsePauseSeconds,
                            range: 0.5...3.0,
                            step: 0.1,
                            width: 42,
                            format: "%.1fs"
                        )
                    }

                    DividerLine()

                    SettingsRow(
                        icon: "forward.circle",
                        title: "Fast pause",
                        subtitle: String(format: "Use %.1fs after speech is established.", container.settings.voiceModeAdaptiveFastPauseSeconds)
                    ) {
                        secondsSlider(
                            value: Bindable(container.settings).voiceModeAdaptiveFastPauseSeconds,
                            range: 0.4...1.2,
                            step: 0.1,
                            width: 42,
                            format: "%.1fs"
                        )
                    }

                    DividerLine()

                    SettingsRow(
                        icon: "waveform",
                        title: "Fast pause after",
                        subtitle: String(format: "Switch after %.1fs of speech.", container.settings.voiceModeAdaptiveMinimumSpeechSeconds)
                    ) {
                        secondsSlider(
                            value: Bindable(container.settings).voiceModeAdaptiveMinimumSpeechSeconds,
                            range: 0.5...3.0,
                            step: 0.1,
                            width: 42,
                            format: "%.1fs"
                        )
                    }
                }
            }

        case .stopPhrase:
            VStack(spacing: 12) {
                SettingsRow(
                    icon: "text.badge.checkmark",
                    title: "Stop phrase",
                    subtitle: "Final phrase is removed after transcription."
                ) {
                    HStack(spacing: 8) {
                        TextField("go ahead", text: Bindable(container.settings).voiceModeStopPhrase)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 220)

                        StopPhraseInfoButton(isSingleWord: isStopPhraseSingleWord)
                    }
                }

                DividerLine()

                SettingsRow(
                    icon: "pause.circle",
                    title: "Fallback pause",
                    subtitle: String(format: "Capture still ends after %.1fs of silence.", container.settings.voiceModeResponsePauseSeconds)
                ) {
                    secondsSlider(
                        value: Bindable(container.settings).voiceModeResponsePauseSeconds,
                        range: 0.5...3.0,
                        step: 0.1,
                        width: 42,
                        format: "%.1fs"
                    )
                }
            }
        }
    }

    private func secondsSlider(
        value: Binding<TimeInterval>,
        range: ClosedRange<TimeInterval>,
        step: TimeInterval,
        width: CGFloat,
        format: String
    ) -> some View {
        HStack(spacing: 10) {
            Slider(value: value, in: range, step: step)
                .frame(width: 190)

            Text(String(format: format, value.wrappedValue))
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .frame(width: width, alignment: .trailing)
        }
    }

    private var adaptivePresetSubtitle: String {
        guard let timing = container.settings.voiceModeAdaptivePausePreset.timing else {
            return "Use custom adaptive pause timings."
        }

        return String(
            format: "Initial %.1fs, fast %.2fs after %.1fs.",
            timing.initialPauseSeconds,
            timing.fastPauseSeconds,
            timing.minimumSpeechSeconds
        )
    }

    private var isStopPhraseSingleWord: Bool {
        container.settings.voiceModeStopPhrase
            .split(whereSeparator: \.isWhitespace)
            .count == 1
    }

    private var selectedVoiceSubtitle: String {
        container.availableSpeechVoices().first(where: { $0.id == container.settings.voiceModeKokoroVoiceIdentifier })?.displayName
            ?? "The selected Kokoro voice is not currently available."
    }

}

private struct ResponseBackendSelectionView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Response backend")
                        .font(.body)

                    Text(container.settings.voiceModeResponseBackend.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Picker(
                    "",
                    selection: Binding(
                        get: { container.settings.voiceModeResponseBackend },
                        set: { container.setVoiceModeResponseBackend($0) }
                    )
                ) {
                    ForEach(VoiceModeResponseBackend.allCases) { backend in
                        Text(backend.title).tag(backend)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 360)

                let backend = container.voiceModeBackendIndicator()
                ResponseBackendStatusPanel(
                    title: backend.title,
                    subtitle: backend.subtitle,
                    isCloud: backend.isCloud
                )
                .frame(width: 360, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 36)
    }
}

private struct ResponseBackendStatusPanel: View {
    let title: String
    let subtitle: String
    let isCloud: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isCloud ? "cloud" : "desktopcomputer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(statusColor.opacity(colorScheme == .light ? 0.12 : 0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var statusColor: Color {
        isCloud ? .orange : .green
    }
}

private struct CloudContextWindowTextField: View {
    @Environment(AppContainer.self) private var container
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("\(AppSettings.suggestedCloudContextWindowTokens)", text: $text)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 140)
            .focused($isFocused)
            .onAppear(perform: syncFromSettings)
            .onSubmit(commitText)
            .onChange(of: isFocused) { _, isFocused in
                if isFocused {
                    syncFromSettings()
                } else {
                    commitText()
                }
            }
            .onChange(of: container.settings.voiceModeCloudContextWindowTokens) { _, _ in
                guard !isFocused else {
                    return
                }

                syncFromSettings()
            }
    }

    private func syncFromSettings() {
        text = container.settings.voiceModeCloudContextWindowTokens.map(String.init) ?? ""
    }

    private func commitText() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            container.settings.voiceModeCloudContextWindowTokens = nil
            text = ""
            return
        }

        let digits = trimmedText.filter(\.isNumber)
        guard let tokens = Int(digits) else {
            syncFromSettings()
            return
        }

        container.settings.voiceModeCloudContextWindowTokens = tokens
        syncFromSettings()
    }
}

private struct StopPhraseInfoButton: View {
    let isSingleWord: Bool

    @State private var isShowingHelp = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            isShowingHelp.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(isSingleWord ? .orange : .secondary)
        .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help("Stop phrase safety")
        .onHover { isHovering in
            isShowingHelp = isHovering
        }
        .popover(isPresented: $isShowingHelp, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Stop Phrase Safety")
                    .font(.headline)
                Text(helpMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 320, alignment: .leading)
        }
    }

    private var helpMessage: String {
        if isSingleWord {
            return "One-word stop phrases are easier to strip accidentally. Two-word command-like phrases are safer. The phrase is removed after transcription, not as an instant recording interrupt."
        }

        return "Two-word command-like phrases are safer than normal words. The phrase is removed after transcription, not as an instant recording interrupt."
    }
}
