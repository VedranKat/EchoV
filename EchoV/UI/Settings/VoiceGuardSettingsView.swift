import SwiftUI

struct VoiceGuardSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Trusted Voice",
                    subtitle: "Use your local voice profile to decide which voice-controlled workflows EchoV accepts."
                )

                SettingsCard("Trusted Voice", subtitle: voiceGuardCardSubtitle) {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "person.wave.2",
                            title: "Enable Trusted Voice",
                            subtitle: voiceGuardMasterSubtitle
                        ) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { container.settings.isVoiceGuardEnabled },
                                    set: { container.setVoiceGuardEnabled($0) }
                                )
                            )
                            .labelsHidden()
                            .disabled(!isVoiceGuardAvailable || container.isVoiceProfileEnrollmentProcessing)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "ear.badge.checkmark",
                            title: "Protect Hands-free",
                            subtitle: "Verify the speaker before Hands-free transcribes and inserts."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).isVoiceGuardEnabledForVoiceGate)
                                .labelsHidden()
                                .disabled(container.isVoiceProfileEnrollmentProcessing)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "text.magnifyingglass",
                            title: "Protect Assistant commands",
                            subtitle: "Verify Computer, Computer text, Continue, and Computer cleanup before acting."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).isVoiceGuardEnabledForVoiceModeCommands)
                                .labelsHidden()
                                .disabled(container.isVoiceProfileEnrollmentProcessing)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "captions.bubble",
                            title: "Protect Assistant requests",
                            subtitle: "Verify the spoken request after an accepted Assistant command."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).isVoiceGuardEnabledForVoiceModeRequests)
                                .labelsHidden()
                                .disabled(container.isVoiceProfileEnrollmentProcessing)
                        }
                    }
                }

                SettingsCard("Verification", subtitle: "Trusted Voice checks stay on this Mac.") {
                    VStack(spacing: 12) {
                        ShortcutHotkeyRow(command: .voiceGuard)

                        DividerLine()

                        SettingsRow(
                            icon: "slider.horizontal.3",
                            title: "Verification mode",
                            subtitle: container.settings.voiceGateSpeakerVerificationMode.subtitle
                        ) {
                            Picker("", selection: Bindable(container.settings).voiceGateSpeakerVerificationMode) {
                                ForEach(VoiceGateSpeakerVerificationMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 210)
                            .disabled(!isVoiceGuardAvailable || container.isVoiceProfileEnrollmentProcessing)
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
                            .disabled(!isVoiceGuardAvailable || container.isVoiceProfileEnrollmentProcessing)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "cpu",
                            title: "Speaker verifier model",
                            subtitle: speakerVerifierSubtitle
                        ) {
                            HStack(spacing: 8) {
                                StatusBadge(text: speakerVerifierStatus.text, tone: speakerVerifierStatus.tone)

                                Button(speakerVerifierInstallButtonTitle) {
                                    Task {
                                        await container.installManagedSpeakerVerifierRuntime()
                                    }
                                }
                                .disabled(container.modelStore.speakerVerifierRuntimeInstallState.isInstalling || isSpeakerVerifierReady)
                            }
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
                                .disabled(!isSpeakerVerifierReady || container.isVoiceProfileEnrollmentProcessing)

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
            Task {
                await container.modelStore.refreshManagedInstallState()
            }
        }
    }

    private var voiceGuardCardSubtitle: String {
        if container.settings.isVoiceGuardEnabled {
            return "Active for the selected workflows."
        }

        return "Off. Target selections are saved for the next time Trusted Voice is enabled."
    }

    private var voiceGuardMasterSubtitle: String {
        guard isSpeakerVerifierReady else {
            return "Install the speaker verifier before enabling Trusted Voice."
        }

        guard let profile = container.speakerProfileStore.profile else {
            return "Record a voice profile before enabling Trusted Voice."
        }

        guard profile.modelID == SpeakerVerifierRuntimeLayout.modelID else {
            return "Re-enroll your voice profile for the ONNX verifier."
        }

        return "Master switch for all selected Trusted Voice targets."
    }

    private var isVoiceGuardAvailable: Bool {
        isSpeakerVerifierReady && isVoiceProfileCompatible
    }

    private var isSpeakerVerifierReady: Bool {
        container.modelStore.speakerVerifierRuntimeInstallState == .installed
    }

    private var isVoiceProfileCompatible: Bool {
        container.speakerProfileStore.profile?.modelID == SpeakerVerifierRuntimeLayout.modelID
    }

    private var speakerVerifierSubtitle: String {
        switch container.modelStore.speakerVerifierRuntimeInstallState {
        case .idle:
            "Downloads the portable ONNX ECAPA speaker model on demand."
        case .installing(let detail):
            detail
        case .installed:
            "\(SpeakerVerifierRuntimeLayout.displayName) is ready."
        case .failed(let detail):
            detail
        }
    }

    private var speakerVerifierStatus: (text: String, tone: StatusBadge.Tone) {
        switch container.modelStore.speakerVerifierRuntimeInstallState {
        case .idle:
            return ("Not installed", .warning)
        case .installing:
            return ("Installing", .active)
        case .installed:
            return ("Ready", .success)
        case .failed:
            return ("Failed", .danger)
        }
    }

    private var speakerVerifierInstallButtonTitle: String {
        switch container.modelStore.speakerVerifierRuntimeInstallState {
        case .idle:
            return "Install"
        case .installing:
            return "Installing..."
        case .installed:
            return "Installed"
        case .failed:
            return "Retry"
        }
    }

    private var voiceProfileSubtitle: String {
        guard isSpeakerVerifierReady else {
            return "Install the speaker verifier before recording a profile."
        }

        guard let profile = container.speakerProfileStore.profile else {
            return "No local profile recorded."
        }

        guard profile.modelID == SpeakerVerifierRuntimeLayout.modelID else {
            return "Recorded with an older verifier. Re-enroll before enabling Trusted Voice."
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

        guard let profile = container.speakerProfileStore.profile else {
            return ("Missing", .warning)
        }

        return profile.modelID == SpeakerVerifierRuntimeLayout.modelID
            ? ("Enrolled", .success)
            : ("Re-enroll", .warning)
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
            I am recording a short voice profile so Trusted Voice can recognize me.
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
