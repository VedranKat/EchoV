import SwiftUI

struct VoiceModeSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var isRecordingVoiceHotkey = false
    @State private var isRecordingTextHotkey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Voice Mode",
                    subtitle: "Say Computer for spoken answers, Slate for text-response sessions, Continue to follow up, or Prime cleanup for selected text."
                )

                SettingsCard("Activation", subtitle: "Keep Voice Mode explicit and local.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "power",
                            title: "Voice Mode",
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
                            subtitle: "Computer speaks, Slate starts text, Continue appends, Prime cleanup rewrites selected text with Prime."
                        ) {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 8) {
                                    StatusBadge(text: "Computer", tone: .active)
                                    StatusBadge(text: "Slate", tone: .success)
                                    StatusBadge(text: "Continue", tone: .neutral)
                                    StatusBadge(text: "Prime cleanup", tone: .warning)
                                }

                                VStack(alignment: .trailing, spacing: 6) {
                                    HStack(spacing: 8) {
                                        StatusBadge(text: "Computer", tone: .active)
                                        StatusBadge(text: "Slate", tone: .success)
                                    }
                                    HStack(spacing: 8) {
                                        StatusBadge(text: "Continue", tone: .neutral)
                                        StatusBadge(text: "Prime cleanup", tone: .warning)
                                    }
                                }
                            }
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "keyboard.badge.ellipsis",
                            title: "Manual voice activation",
                            subtitle: "Start spoken-answer listening without saying Computer."
                        ) {
                            HStack(spacing: 8) {
                                KeyboardShortcutChip(text: container.settings.voiceModeActivationHotkey?.displayName ?? "Not set")

                                Button("Change") {
                                    isRecordingVoiceHotkey = true
                                }

                                Button("Clear") {
                                    container.setVoiceModeActivationHotkey(nil)
                                }
                                .disabled(container.settings.voiceModeActivationHotkey == nil)
                            }
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "keyboard.badge.ellipsis",
                            title: "Manual text activation",
                            subtitle: "Start text-response listening without saying Slate."
                        ) {
                            HStack(spacing: 8) {
                                KeyboardShortcutChip(text: container.settings.voiceModeTextActivationHotkey?.displayName ?? "Not set")

                                Button("Change") {
                                    isRecordingTextHotkey = true
                                }

                                Button("Clear") {
                                    container.setVoiceModeTextActivationHotkey(nil)
                                }
                                .disabled(container.settings.voiceModeTextActivationHotkey == nil)
                            }
                        }
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
                            subtitle: "Review, edit, or cancel the prompt before the LLM sees it."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).isVoiceModePromptPreviewEnabled)
                                .labelsHidden()
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "rectangle.inset.filled.and.person.filled",
                            title: "Status HUD",
                            subtitle: "Show a compact floating Voice Mode status panel."
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
                            icon: "arrow.triangle.branch",
                            title: "Response backend",
                            subtitle: container.settings.voiceModeResponseBackend.subtitle
                        ) {
                            HStack(spacing: 10) {
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
                                .frame(width: 320)

                                let backend = container.voiceModeBackendIndicator()
                                VoiceModeBackendIndicator(
                                    title: backend.title,
                                    subtitle: backend.subtitle,
                                    isCloud: backend.isCloud
                                )
                            }
                        }
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

                SettingsCard("Text Response", subtitle: "Slate notifications stay final-only; chat follow-ups can stream.") {
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
        .sheet(isPresented: $isRecordingVoiceHotkey) {
            HotkeyRecorderSheet(
                title: "Set Voice Mode Voice",
                onCancel: {
                    isRecordingVoiceHotkey = false
                },
                onCapture: { binding in
                    container.setVoiceModeActivationHotkey(binding)
                    isRecordingVoiceHotkey = false
                }
            )
        }
        .sheet(isPresented: $isRecordingTextHotkey) {
            HotkeyRecorderSheet(
                title: "Set Voice Mode Text",
                onCancel: {
                    isRecordingTextHotkey = false
                },
                onCapture: { binding in
                    container.setVoiceModeTextActivationHotkey(binding)
                    isRecordingTextHotkey = false
                }
            )
        }
    }

    private var voiceModeSubtitle: String {
        if container.settings.isVoiceModeEnabled {
            return "Listening for Computer, Slate, Continue, or Prime cleanup while EchoV is running."
        }

        return "Voice Mode starts only when this is enabled."
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
