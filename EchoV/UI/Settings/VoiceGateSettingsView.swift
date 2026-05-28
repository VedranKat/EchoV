import SwiftUI

struct VoiceGateSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var isRecordingHotkey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Voice Gate",
                    subtitle: "Let EchoV listen locally, record when speech starts, and transcribe after silence."
                )

                SettingsCard("Voice Gate", subtitle: "Let EchoV listen locally, record when speech starts, and transcribe after silence.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "ear",
                            title: "Voice Gate hotkey",
                            subtitle: "Press once to listen for speech, then press again to mute."
                        ) {
                            HStack(spacing: 8) {
                                KeyboardShortcutChip(text: container.settings.voiceGateHotkey?.displayName ?? "Not set")

                                Button("Change") {
                                    isRecordingHotkey = true
                                }

                                Button("Clear") {
                                    container.setVoiceGateHotkey(nil)
                                }
                                .disabled(container.settings.voiceGateHotkey == nil)
                            }
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "timer",
                            title: "Silence timeout",
                            subtitle: container.settings.voiceGateSilenceTimeout.subtitle
                        ) {
                            Picker("", selection: Bindable(container.settings).voiceGateSilenceTimeout) {
                                ForEach(VoiceGateSilenceTimeout.allCases) { timeout in
                                    Text(timeout.title).tag(timeout)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 250)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "waveform",
                            title: "Sensitivity",
                            subtitle: container.settings.voiceGateSensitivity.subtitle
                        ) {
                            Picker("", selection: Bindable(container.settings).voiceGateSensitivity) {
                                ForEach(VoiceGateSensitivity.allCases) { sensitivity in
                                    Text(sensitivity.title).tag(sensitivity)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 250)
                        }
                    }
                }
            }
            .padding(24)
        }
        .settingsPageBackground()
        .sheet(isPresented: $isRecordingHotkey) {
            HotkeyRecorderSheet(
                title: "Set Voice Gate",
                onCancel: {
                    isRecordingHotkey = false
                },
                onCapture: { binding in
                    container.setVoiceGateHotkey(binding)
                    isRecordingHotkey = false
                }
            )
        }
    }
}
