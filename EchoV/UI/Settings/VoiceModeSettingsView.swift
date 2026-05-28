import SwiftUI

struct VoiceModeSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var isRecordingHotkey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Voice Mode",
                    subtitle: "Respond locally after Computer, your request, and a pause."
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
                            title: "Activation phrase",
                            subtitle: "Requires the isolated word."
                        ) {
                            StatusBadge(text: "Computer", tone: .active)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "keyboard.badge.ellipsis",
                            title: "Manual activation",
                            subtitle: "Start listening for a request without the activation phrase."
                        ) {
                            HStack(spacing: 8) {
                                KeyboardShortcutChip(text: container.settings.voiceModeActivationHotkey?.displayName ?? "Not set")

                                Button("Change") {
                                    isRecordingHotkey = true
                                }

                                Button("Clear") {
                                    container.setVoiceModeActivationHotkey(nil)
                                }
                                .disabled(container.settings.voiceModeActivationHotkey == nil)
                            }
                        }
                    }
                }

                SettingsCard("Response", subtitle: "Control when EchoV sends the prompt and where the answer comes from.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "timer",
                            title: "Respond after pause",
                            subtitle: String(format: "Send the request after %.1fs of silence.", container.settings.voiceModeResponsePauseSeconds)
                        ) {
                            HStack(spacing: 10) {
                                Slider(
                                    value: Bindable(container.settings).voiceModeResponsePauseSeconds,
                                    in: 0.5...3.0,
                                    step: 0.1
                                )
                                .frame(width: 190)

                                Text(String(format: "%.1fs", container.settings.voiceModeResponsePauseSeconds))
                                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                                    .frame(width: 42, alignment: .trailing)
                            }
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "arrow.triangle.branch",
                            title: "Response backend",
                            subtitle: container.settings.voiceModeResponseBackend.subtitle
                        ) {
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
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "bubble.left.and.text.bubble.right",
                            title: "Delivery",
                            subtitle: container.settings.voiceModeResponseDelivery.subtitle
                        ) {
                            Picker(
                                "",
                                selection: Binding(
                                    get: { container.settings.voiceModeResponseDelivery },
                                    set: { container.setVoiceModeResponseDelivery($0) }
                                )
                            ) {
                                ForEach(VoiceModeResponseDelivery.allCases) { delivery in
                                    Text(delivery.title).tag(delivery)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 180)
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

                if container.settings.voiceModeResponseDelivery == .textResponse {
                    SettingsCard("Text Response", subtitle: "Notification replies stay final-only; chat follow-ups can stream.") {
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
                }

                if container.settings.voiceModeResponseDelivery == .spoken {
                    SettingsCard("Kokoro", subtitle: "Use Kokoro CoreML for Voice Mode responses.") {
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
            }
            .padding(24)
        }
        .settingsPageBackground()
        .sheet(isPresented: $isRecordingHotkey) {
            HotkeyRecorderSheet(
                title: "Set Voice Mode",
                onCancel: {
                    isRecordingHotkey = false
                },
                onCapture: { binding in
                    container.setVoiceModeActivationHotkey(binding)
                    isRecordingHotkey = false
                }
            )
        }
    }

    private var voiceModeSubtitle: String {
        if container.settings.isVoiceModeEnabled {
            return "Listening for Computer while EchoV is running."
        }

        return "Voice Mode starts only when this is enabled."
    }

    private var selectedVoiceSubtitle: String {
        container.availableSpeechVoices().first(where: { $0.id == container.settings.voiceModeKokoroVoiceIdentifier })?.displayName
            ?? "The selected Kokoro voice is not currently available."
    }

}
