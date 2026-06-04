import SwiftUI

struct LiveSubtitleSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Live Subtitles",
                    subtitle: "Caption selected audio with Parakeet, then optionally clean or translate with the local Prime llama.cpp model."
                )

                SettingsCard("Run", subtitle: "Choose the audio source and start the subtitle overlay.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "captions.bubble",
                            title: "Live Subtitles",
                            subtitle: liveSubtitleRunSubtitle
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { container.settings.isLiveSubtitlesEnabled },
                                    set: { container.setLiveSubtitlesEnabled($0) }
                                )
                            )
                            .labelsHidden()
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "waveform.badge.mic",
                            title: "Audio source",
                            subtitle: audioSourceSubtitle
                        ) {
                            Picker(
                                "Audio source",
                                selection: Binding(
                                    get: { selectedAudioDeviceID ?? "" },
                                    set: { container.setLiveSubtitleAudioDeviceID($0.isEmpty ? nil : $0) }
                                )
                            ) {
                                Text("System Default").tag("")
                                ForEach(audioDevices) { device in
                                    Text(device.name).tag(device.id)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 280)
                        }

                        if let blackHoleDevice, container.settings.selectedLiveSubtitleAudioDeviceID != blackHoleDevice.id {
                            DividerLine()

                            SettingsRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "BlackHole detected",
                                subtitle: "Use BlackHole when routing system or meeting audio into EchoV."
                            ) {
                                Button("Use BlackHole") {
                                    container.setLiveSubtitleAudioDeviceID(blackHoleDevice.id)
                                }
                            }
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "info.circle",
                            title: "Best with BlackHole",
                            subtitle: "For meetings, videos, and system audio, route audio into BlackHole and select it here. Microphones work too, but they also pick up room sound."
                        ) {
                            StatusBadge(text: blackHoleDevice == nil ? "Not detected" : "Available", tone: blackHoleDevice == nil ? .warning : .success)
                        }

                        DividerLine()

                        ShortcutHotkeyRow(command: .liveSubtitles)
                    }
                }

                SettingsCard("Captioning", subtitle: "Keep raw captions live; use Prime only when it can keep up.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "text.bubble",
                            title: "Mode",
                            subtitle: container.settings.liveSubtitleMode.subtitle
                        ) {
                            Picker(
                                "",
                                selection: Binding(
                                    get: { container.settings.liveSubtitleMode },
                                    set: { container.setLiveSubtitleMode($0) }
                                )
                            ) {
                                ForEach(LiveSubtitleMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 300)
                        }

                        if container.settings.liveSubtitleMode == .translatedSubtitles {
                            DividerLine()

                            SettingsRow(
                                icon: "globe",
                                title: "Target language",
                                subtitle: "Prime translates each subtitle chunk into this language."
                            ) {
                                TextField(
                                    "English",
                                    text: Binding(
                                        get: { container.settings.liveSubtitleTargetLanguage },
                                        set: { container.settings.liveSubtitleTargetLanguage = $0 }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                            }
                        }

                        if container.settings.liveSubtitleMode.requiresPostProcessing {
                            DividerLine()

                            SettingsRow(
                                icon: "cpu",
                                title: "Prime model",
                                subtitle: container.liveSubtitlePostProcessingIndicator().subtitle
                            ) {
                                let indicator = container.liveSubtitlePostProcessingIndicator()
                                StatusBadge(text: indicator.title, tone: indicator.tone)
                            }

                            if container.settings.liveSubtitleMode == .cleanedCaptions {
                                DividerLine()

                                SettingsRow(
                                    icon: "bolt",
                                    title: "Show raw while Prime works",
                                    subtitle: "Raw Parakeet captions appear first, then Prime replaces them when it is fast enough."
                                ) {
                                    Toggle("", isOn: Bindable(container.settings).liveSubtitleShowsRawWhileProcessing)
                                        .labelsHidden()
                                }
                            }
                        }
                    }
                }

                SettingsCard("Chunking", subtitle: "Silence detection splits continuous audio into subtitle-sized chunks.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "slider.horizontal.3",
                            title: "Preset",
                            subtitle: container.settings.liveSubtitleChunkPreset.subtitle
                        ) {
                            Picker(
                                "",
                                selection: Bindable(container.settings).liveSubtitleChunkPreset
                            ) {
                                ForEach(LiveSubtitleChunkPreset.allCases) { preset in
                                    Text(preset.title).tag(preset)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 340)
                        }

                        DividerLine()

                        if container.settings.liveSubtitleChunkPreset == .custom {
                            customChunkControls
                        } else {
                            SettingsRow(
                                icon: "timer",
                                title: "Active timing",
                                subtitle: activeChunkSummary
                            ) {
                                StatusBadge(text: container.settings.liveSubtitleChunkPreset.title, tone: .active)
                            }
                        }
                    }
                }

                SettingsCard("Overlay", subtitle: "Tune the bottom subtitle panel for readability.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "textformat.size",
                            title: "Text size",
                            subtitle: String(format: "%.0f pt subtitle text.", container.settings.liveSubtitleTextSize)
                        ) {
                            valueSlider(
                                value: Bindable(container.settings).liveSubtitleTextSize,
                                range: 18...48,
                                step: 1,
                                width: 46,
                                format: "%.0f"
                            )
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "text.alignleft",
                            title: "Max lines",
                            subtitle: "Show up to this many recent subtitle rows at once."
                        ) {
                            Picker(
                                "",
                                selection: Bindable(container.settings).liveSubtitleMaxLines
                            ) {
                                Text("1").tag(1)
                                Text("2").tag(2)
                                Text("3").tag(3)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "arrow.down.to.line",
                            title: "Bottom margin",
                            subtitle: String(format: "%.0f px above the screen edge.", container.settings.liveSubtitleBottomMargin)
                        ) {
                            valueSlider(
                                value: Bindable(container.settings).liveSubtitleBottomMargin,
                                range: 20...180,
                                step: 1,
                                width: 52,
                                format: "%.0f"
                            )
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "hourglass",
                            title: "Hold after silence",
                            subtitle: String(format: "Keep subtitles visible for %.1fs after the last chunk.", container.settings.liveSubtitleHoldSeconds)
                        ) {
                            valueSlider(
                                value: Bindable(container.settings).liveSubtitleHoldSeconds,
                                range: 0.8...8.0,
                                step: 0.1,
                                width: 48,
                                format: "%.1fs"
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .settingsPageBackground()
        .onAppear {
            container.clearUnavailableLiveSubtitleAudioDeviceSelection()
        }
    }

    private var customChunkControls: some View {
        VStack(spacing: 12) {
            SettingsRow(
                icon: "timer",
                title: "Max chunk",
                subtitle: String(format: "Force a subtitle chunk every %.1fs during continuous speech.", container.settings.liveSubtitleMaxChunkSeconds)
            ) {
                valueSlider(
                    value: Bindable(container.settings).liveSubtitleMaxChunkSeconds,
                    range: 1.5...12.0,
                    step: 0.1,
                    width: 48,
                    format: "%.1fs"
                )
            }

            DividerLine()

            SettingsRow(
                icon: "pause.circle",
                title: "Silence timeout",
                subtitle: String(format: "End a chunk after %.2fs of silence.", container.settings.liveSubtitleSilenceTimeoutSeconds)
            ) {
                valueSlider(
                    value: Bindable(container.settings).liveSubtitleSilenceTimeoutSeconds,
                    range: 0.25...2.5,
                    step: 0.05,
                    width: 52,
                    format: "%.2fs"
                )
            }

            DividerLine()

            SettingsRow(
                icon: "waveform.path",
                title: "Minimum speech",
                subtitle: String(format: "Discard chunks shorter than %.2fs of speech.", container.settings.liveSubtitleMinimumSpeechSeconds)
            ) {
                valueSlider(
                    value: Bindable(container.settings).liveSubtitleMinimumSpeechSeconds,
                    range: 0.15...1.5,
                    step: 0.05,
                    width: 52,
                    format: "%.2fs"
                )
            }

            DividerLine()

            SettingsRow(
                icon: "backward.end.circle",
                title: "Pre-roll",
                subtitle: String(format: "Keep %.2fs before speech starts.", container.settings.liveSubtitlePreRollSeconds)
            ) {
                valueSlider(
                    value: Bindable(container.settings).liveSubtitlePreRollSeconds,
                    range: 0.0...1.0,
                    step: 0.05,
                    width: 52,
                    format: "%.2fs"
                )
            }

            DividerLine()

            SettingsRow(
                icon: "square.stack.3d.forward.dottedline",
                title: "Overlap",
                subtitle: String(format: "Replay %.2fs across forced chunk boundaries.", container.settings.liveSubtitleOverlapSeconds)
            ) {
                valueSlider(
                    value: Bindable(container.settings).liveSubtitleOverlapSeconds,
                    range: 0.0...0.75,
                    step: 0.05,
                    width: 52,
                    format: "%.2fs"
                )
            }

            DividerLine()

            SettingsRow(
                icon: "dial.high",
                title: "Sensitivity",
                subtitle: container.settings.liveSubtitleSensitivity.subtitle
            ) {
                Picker(
                    "",
                    selection: Bindable(container.settings).liveSubtitleSensitivity
                ) {
                    ForEach(VoiceGateSensitivity.allCases) { sensitivity in
                        Text(sensitivity.title).tag(sensitivity)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 260)
            }
        }
    }

    private var liveSubtitleRunSubtitle: String {
        if container.liveSubtitles.isRunning {
            let delay = container.liveSubtitles.liveDelaySeconds
            if delay >= 0.1 {
                return String(format: "%@ Delay %.1fs.", container.liveSubtitles.statusDetail, delay)
            }
            return container.liveSubtitles.statusDetail
        }

        return "Start captions from the selected input and show the bottom overlay."
    }

    private var audioDevices: [MicrophoneDevice] {
        container.availableLiveSubtitleAudioDevices()
    }

    private var blackHoleDevice: MicrophoneDevice? {
        audioDevices.first { $0.name.localizedCaseInsensitiveContains("blackhole") }
    }

    private var selectedAudioDeviceID: String? {
        guard let selectedID = container.settings.selectedLiveSubtitleAudioDeviceID,
              audioDevices.contains(where: { $0.id == selectedID })
        else {
            return nil
        }

        return selectedID
    }

    private var audioSourceSubtitle: String {
        if let selectedID = selectedAudioDeviceID,
           let device = audioDevices.first(where: { $0.id == selectedID }) {
            return "Using \(device.name)."
        }

        if blackHoleDevice != nil {
            return "System default input. BlackHole is available for routed app audio."
        }

        return "System default input. Install or route BlackHole to caption system audio."
    }

    private var activeChunkSummary: String {
        let configuration = container.settings.liveSubtitleChunkConfiguration
        return String(
            format: "Max %.1fs, silence %.2fs, pre-roll %.2fs, overlap %.2fs.",
            configuration.maxChunkSeconds,
            configuration.silenceTimeoutSeconds,
            configuration.preRollSeconds,
            configuration.overlapSeconds
        )
    }

    private func valueSlider(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        width: CGFloat,
        format: String
    ) -> some View {
        HStack(spacing: 10) {
            Slider(value: value, in: range, step: step)
                .frame(width: 180)

            Text(String(format: format, value.wrappedValue))
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .frame(width: width, alignment: .trailing)
        }
    }
}
