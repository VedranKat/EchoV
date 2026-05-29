import SwiftUI

struct VoiceGateSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Voice Gate",
                    subtitle: "Let EchoV listen locally, record when speech starts, and transcribe after silence."
                )

                SettingsCard("Voice Gate", subtitle: "Let EchoV listen locally, record when speech starts, and transcribe after silence.") {
                    VStack(spacing: 12) {
                        ShortcutHotkeyRow(command: .voiceGate)

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
    }
}
