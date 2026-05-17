import SwiftUI

struct VoiceGateSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var isRecordingHotkey = false
    @State private var isRecordingVerifierHotkey = false

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

                        DividerLine()

                        SettingsRow(
                            icon: "person.wave.2",
                            title: "My voice only",
                            subtitle: speakerMatchSubtitle
                        ) {
                            Toggle("", isOn: Bindable(container.settings).isVoiceGateSpeakerMatchEnabled)
                                .labelsHidden()
                                .disabled(container.speakerProfileStore.profile == nil || container.isVoiceProfileEnrollmentProcessing)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "keyboard.badge.ellipsis",
                            title: "Verifier hotkey",
                            subtitle: "Toggle My Voice Only on or off."
                        ) {
                            HStack(spacing: 8) {
                                KeyboardShortcutChip(text: container.settings.voiceGateVerifierToggleHotkey?.displayName ?? "Not set")

                                Button("Change") {
                                    isRecordingVerifierHotkey = true
                                }

                                Button("Clear") {
                                    container.setVoiceGateVerifierToggleHotkey(nil)
                                }
                                .disabled(container.settings.voiceGateVerifierToggleHotkey == nil)
                            }
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "slider.horizontal.3",
                            title: "Match strictness",
                            subtitle: container.settings.voiceGateSpeakerMatchStrictness.subtitle
                        ) {
                            Picker("", selection: Bindable(container.settings).voiceGateSpeakerMatchStrictness) {
                                ForEach(VoiceGateSpeakerMatchStrictness.allCases) { strictness in
                                    Text(strictness.title).tag(strictness)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 190)
                            .disabled(!container.settings.isVoiceGateSpeakerMatchEnabled)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "person.crop.circle.badge.checkmark",
                            title: "Voice profile",
                            subtitle: voiceProfileSubtitle
                        ) {
                            HStack(spacing: 8) {
                                StatusBadge(text: voiceProfileStatus.text, tone: voiceProfileStatus.tone)

                                Button(enrollmentButtonTitle) {
                                    toggleEnrollment()
                                }

                                Button("Delete") {
                                    container.deleteVoiceProfile()
                                }
                                .disabled(container.speakerProfileStore.profile == nil || container.isVoiceProfileEnrollmentRecording || container.isVoiceProfileEnrollmentProcessing)
                            }
                        }

                        if container.isVoiceProfileEnrollmentRecording {
                            VoiceProfileEnrollmentPrompt()
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "trash",
                            title: "Remove all voice data",
                            subtitle: "Delete saved speaker embeddings from this Mac."
                        ) {
                            Button("Remove All", role: .destructive) {
                                container.deleteAllVoiceProfiles()
                            }
                            .disabled(container.speakerProfileStore.profile == nil || container.isVoiceProfileEnrollmentRecording || container.isVoiceProfileEnrollmentProcessing)
                        }
                    }
                }
            }
            .padding(24)
        }
        .settingsPageBackground()
        .onAppear {
            container.speakerProfileStore.refresh()
        }
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
        .sheet(isPresented: $isRecordingVerifierHotkey) {
            HotkeyRecorderSheet(
                title: "Set Verifier Hotkey",
                onCancel: {
                    isRecordingVerifierHotkey = false
                },
                onCapture: { binding in
                    container.setVoiceGateVerifierToggleHotkey(binding)
                    isRecordingVerifierHotkey = false
                }
            )
        }
    }

    private var speakerMatchSubtitle: String {
        guard container.speakerProfileStore.profile != nil else {
            return "Record a voice profile before requiring speaker match."
        }

        return "Check each Voice Gate utterance before sending it to Parakeet."
    }

    private var voiceProfileSubtitle: String {
        guard let profile = container.speakerProfileStore.profile else {
            return "No local profile recorded."
        }

        return "Created \(profile.createdAt.formatted(date: .abbreviated, time: .shortened))."
    }

    private var voiceProfileStatus: (text: String, tone: StatusBadge.Tone) {
        if container.isVoiceProfileEnrollmentRecording {
            return ("Recording", .active)
        }

        if container.isVoiceProfileEnrollmentProcessing {
            return ("Creating", .active)
        }

        return container.speakerProfileStore.profile == nil
            ? ("Missing", .warning)
            : ("Enrolled", .success)
    }

    private var enrollmentButtonTitle: String {
        if container.isVoiceProfileEnrollmentRecording {
            return "Finish"
        }

        if container.isVoiceProfileEnrollmentProcessing {
            return "Creating..."
        }

        return container.speakerProfileStore.profile == nil ? "Record" : "Replace"
    }

    private func toggleEnrollment() {
        Task {
            if container.isVoiceProfileEnrollmentRecording {
                await container.finishVoiceProfileEnrollment()
            } else if !container.isVoiceProfileEnrollmentProcessing {
                await container.startVoiceProfileEnrollment()
            }
        }
    }
}

private struct VoiceProfileEnrollmentPrompt: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Read this in your normal dictation voice", systemImage: "text.quote")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("""
            This is my normal speaking voice for EchoV.
            I am recording a short voice profile so Voice Gate can recognize me.
            I usually speak at this volume and distance from the microphone.
            """)
            .font(.callout)
            .foregroundStyle(.primary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator.opacity(colorScheme == .light ? 0.22 : 0.45))
        }
    }
}
