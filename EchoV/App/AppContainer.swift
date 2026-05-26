import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {
    private enum HotkeyID {
        static let toggle = UInt32(1)
        static let pushToTalk = UInt32(2)
        static let voiceGate = UInt32(3)
        static let primeToggle = UInt32(4)
        static let voiceGateVerifierToggle = UInt32(5)
    }

    private enum RecordingTrigger {
        case toggle
        case pushToTalk
        case voiceGate
    }

    let appState: AppState
    let permissionState: PermissionState
    let settings: AppSettings
    let pipeline: DictationPipeline
    let microphonePermission: MicrophonePermissionService
    let accessibilityPermission: AccessibilityPermissionService
    let startupPermission: StartupPermissionService
    let modelStore: ModelStore
    let historyStore: TranscriptHistoryStore
    let temporaryAudioStore: TemporaryAudioStore
    let licensesStore: LicensesStore
    let speakerProfileStore: SpeakerProfileStore

    private let hotkeyService: any HotkeyService
    private let voiceGateCapture: VoiceActivatedAudioCapture
    private let speakerVerificationService: any SpeakerVerificationService
    private let voiceGateVerificationWindows: AudioWindowExtractor
    private let voiceProfileEnrollmentRecorder: any AudioRecorder
    private var hasStarted = false
    private var recordingTrigger: RecordingTrigger?
    private var isVoiceGateArmed = false
    private var voiceProfileEnrollmentRecording: RecordedAudio?
    var isVoiceProfileEnrollmentRecording = false
    var isVoiceProfileEnrollmentProcessing = false

    private init(
        appState: AppState,
        permissionState: PermissionState,
        settings: AppSettings,
        pipeline: DictationPipeline,
        microphonePermission: MicrophonePermissionService,
        accessibilityPermission: AccessibilityPermissionService,
        startupPermission: StartupPermissionService,
        modelStore: ModelStore,
        historyStore: TranscriptHistoryStore,
        temporaryAudioStore: TemporaryAudioStore,
        licensesStore: LicensesStore,
        speakerProfileStore: SpeakerProfileStore,
        hotkeyService: any HotkeyService,
        voiceGateCapture: VoiceActivatedAudioCapture,
        speakerVerificationService: any SpeakerVerificationService,
        voiceGateVerificationWindows: AudioWindowExtractor,
        voiceProfileEnrollmentRecorder: any AudioRecorder
    ) {
        self.appState = appState
        self.permissionState = permissionState
        self.settings = settings
        self.pipeline = pipeline
        self.microphonePermission = microphonePermission
        self.accessibilityPermission = accessibilityPermission
        self.startupPermission = startupPermission
        self.modelStore = modelStore
        self.historyStore = historyStore
        self.temporaryAudioStore = temporaryAudioStore
        self.licensesStore = licensesStore
        self.speakerProfileStore = speakerProfileStore
        self.hotkeyService = hotkeyService
        self.voiceGateCapture = voiceGateCapture
        self.speakerVerificationService = speakerVerificationService
        self.voiceGateVerificationWindows = voiceGateVerificationWindows
        self.voiceProfileEnrollmentRecorder = voiceProfileEnrollmentRecorder
    }

    static func bootstrap() -> AppContainer {
        let settings = AppSettings()
        let appState = AppState()
        let permissionState = PermissionState()
        let microphonePermission = MicrophonePermissionService()
        let accessibilityPermission = AccessibilityPermissionService()
        let startupPermission = StartupPermissionService()
        let modelStore = ModelStore(proxySettings: { settings.proxySettings })
        let historyStore = TranscriptHistoryStore()
        let temporaryAudioStore = TemporaryAudioStore()
        let licensesStore = LicensesStore()

        let pipeline = DictationPipeline(
            appState: appState,
            recorder: AVFoundationAudioRecorder(
                microphonePermission: microphonePermission,
                selectedMicrophoneDeviceID: { settings.selectedMicrophoneDeviceID }
            ),
            normalizer: AudioNormalizer(),
            asrEngine: UnconfiguredASREngine(),
            cleanupEngine: GemmaPrimeTextCleanupEngine(
                textGenerationEngine: UnconfiguredLocalTextGenerationEngine()
            ),
            insertion: PasteInsertionService(
                accessibilityPermission: accessibilityPermission,
                clipboardInsertionMode: { settings.clipboardInsertionMode }
            ),
            history: historyStore,
            temporaryAudioStore: temporaryAudioStore,
            isHistoryEnabled: { settings.isHistoryEnabled },
            shouldDeleteTemporaryAudio: { settings.shouldDeleteTemporaryAudio },
            isPostProcessingEnabled: { settings.isPostProcessingEnabled },
            postProcessingLevel: { settings.postProcessingLevel },
            onStateChanged: { appState.notifyStatusChanged() }
        )

        return AppContainer(
            appState: appState,
            permissionState: permissionState,
            settings: settings,
            pipeline: pipeline,
            microphonePermission: microphonePermission,
            accessibilityPermission: accessibilityPermission,
            startupPermission: startupPermission,
            modelStore: modelStore,
            historyStore: historyStore,
            temporaryAudioStore: temporaryAudioStore,
            licensesStore: licensesStore,
            speakerProfileStore: SpeakerProfileStore(),
            hotkeyService: CarbonHotkeyService(),
            voiceGateCapture: VoiceActivatedAudioCapture(
                microphonePermission: microphonePermission,
                selectedMicrophoneDeviceID: { settings.selectedMicrophoneDeviceID }
            ),
            speakerVerificationService: ONNXSpeakerVerificationService(),
            voiceGateVerificationWindows: AudioWindowExtractor(),
            voiceProfileEnrollmentRecorder: AVFoundationAudioRecorder(
                microphonePermission: microphonePermission,
                minimumDuration: 3,
                selectedMicrophoneDeviceID: { settings.selectedMicrophoneDeviceID }
            )
        )
    }

    func start() {
        hasStarted = true
        refreshPermissions()

        Task {
            await historyStore.load()
            await modelStore.restoreSelection()
            if !SpeakerVerifierRuntimeLayout.isInstalled()
                || speakerProfileStore.profile?.modelID != SpeakerVerifierRuntimeLayout.modelID {
                settings.isVoiceGateSpeakerMatchEnabled = false
            }
            configureASREngineFromSelectedModel()
            configurePostProcessingEngineFromSelectedModel()
        }

        registerHotkeys()
    }

    func stop() async {
        hasStarted = false
        hotkeyService.unregister()
        voiceGateCapture.stop()
        if isVoiceProfileEnrollmentRecording {
            _ = try? await voiceProfileEnrollmentRecorder.stop()
            isVoiceProfileEnrollmentRecording = false
            voiceProfileEnrollmentRecording = nil
        }
        await pipeline.shutdownCleanupEngine()
    }

    func setToggleHotkey(_ binding: HotkeyBinding?) {
        guard isHotkeyAvailable(binding, excluding: \.toggleHotkey) else {
            appState.lastError = .hotkeyUnavailable(details: "Toggle cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        guard binding == nil || binding != settings.pushToTalkHotkey else {
            appState.lastError = .hotkeyUnavailable(details: "Toggle and push-to-talk cannot use the same hotkey.")
            return
        }

        guard binding == nil || binding != settings.voiceGateHotkey else {
            appState.lastError = .hotkeyUnavailable(details: "Toggle and Voice Gate cannot use the same hotkey.")
            return
        }

        settings.toggleHotkey = binding
        registerHotkeys()
    }

    func setPushToTalkHotkey(_ binding: HotkeyBinding?) {
        guard isHotkeyAvailable(binding, excluding: \.pushToTalkHotkey) else {
            appState.lastError = .hotkeyUnavailable(details: "Push-to-talk cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        guard binding == nil || binding != settings.toggleHotkey else {
            appState.lastError = .hotkeyUnavailable(details: "Toggle and push-to-talk cannot use the same hotkey.")
            return
        }

        guard binding == nil || binding != settings.voiceGateHotkey else {
            appState.lastError = .hotkeyUnavailable(details: "Push-to-talk and Voice Gate cannot use the same hotkey.")
            return
        }

        settings.pushToTalkHotkey = binding
        registerHotkeys()
    }

    func setVoiceGateHotkey(_ binding: HotkeyBinding?) {
        guard isHotkeyAvailable(binding, excluding: \.voiceGateHotkey) else {
            appState.lastError = .hotkeyUnavailable(details: "Voice Gate cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        guard binding == nil || binding != settings.toggleHotkey else {
            appState.lastError = .hotkeyUnavailable(details: "Voice Gate and toggle cannot use the same hotkey.")
            return
        }

        guard binding == nil || binding != settings.pushToTalkHotkey else {
            appState.lastError = .hotkeyUnavailable(details: "Voice Gate and push-to-talk cannot use the same hotkey.")
            return
        }

        settings.voiceGateHotkey = binding
        registerHotkeys()
    }

    func setPrimeToggleHotkey(_ binding: HotkeyBinding?) {
        guard isHotkeyAvailable(binding, excluding: \.primeToggleHotkey) else {
            appState.lastError = .hotkeyUnavailable(details: "Prime cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        settings.primeToggleHotkey = binding
        registerHotkeys()
    }

    func setVoiceGateVerifierToggleHotkey(_ binding: HotkeyBinding?) {
        guard isHotkeyAvailable(binding, excluding: \.voiceGateVerifierToggleHotkey) else {
            appState.lastError = .hotkeyUnavailable(details: "Voice Gate verifier cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        settings.voiceGateVerifierToggleHotkey = binding
        registerHotkeys()
    }

    func resetHotkeysToDefaults() {
        settings.resetHotkeysToDefaults()
        registerHotkeys()
    }

    func resetDictationHotkeysToDefaults() {
        settings.resetDictationHotkeysToDefaults()
        registerHotkeys()
    }

    func startVoiceProfileEnrollment() async {
        guard !isVoiceProfileEnrollmentRecording else {
            return
        }

        guard SpeakerVerifierRuntimeLayout.isInstalled() else {
            appState.lastError = .speakerVerificationFailed(details: "Install the speaker verifier before enrolling a voice profile.")
            appState.lastDetail = "Speaker verifier is not installed."
            appState.notifyStatusChanged()
            return
        }

        guard recordingTrigger == nil, appState.state.canStartRecording else {
            appState.lastError = .recordingFailed(details: "Stop the current recording before enrolling a voice profile.")
            return
        }

        do {
            voiceProfileEnrollmentRecording = try await voiceProfileEnrollmentRecorder.start()
            isVoiceProfileEnrollmentRecording = true
            appState.lastError = nil
            appState.lastDetail = "Recording your voice profile. Speak naturally for at least a few seconds."
            setState(.recording(startedAt: Date()))
        } catch let error as AppError {
            appState.lastError = error
            setState(.failed(error))
        } catch {
            let appError = AppError.recordingFailed(details: error.localizedDescription)
            appState.lastError = appError
            setState(.failed(appError))
        }
    }

    func finishVoiceProfileEnrollment() async {
        guard isVoiceProfileEnrollmentRecording else {
            return
        }

        do {
            let recordedAudio = try await voiceProfileEnrollmentRecorder.stop()
            isVoiceProfileEnrollmentRecording = false
            isVoiceProfileEnrollmentProcessing = true
            voiceProfileEnrollmentRecording = nil
            appState.lastDetail = "Creating your local voice profile..."
            setState(.transcribing(status: "Creating voice profile..."))

            DiagnosticLog.write("Voice profile enrollment started audio=\(recordedAudio.fileURL.path)")
            let profile = try await speakerVerificationService.enroll(audioURL: recordedAudio.fileURL)
            try speakerProfileStore.save(profile)
            DiagnosticLog.write("Voice profile enrollment completed dimensions=\(profile.embedding.count)")
            temporaryAudioStore.delete([recordedAudio.fileURL])

            isVoiceProfileEnrollmentProcessing = false
            appState.lastError = nil
            appState.lastDetail = "Voice profile enrolled."
            setState(.completed(Transcript(text: "Voice profile enrolled.", segments: [])))
        } catch let error as AppError {
            isVoiceProfileEnrollmentRecording = false
            isVoiceProfileEnrollmentProcessing = false
            voiceProfileEnrollmentRecording = nil
            DiagnosticLog.write("Voice profile enrollment AppError: \(error.userMessage) details=\(error.technicalDetails ?? "none")")
            appState.lastError = error
            setState(.failed(error))
        } catch {
            isVoiceProfileEnrollmentRecording = false
            isVoiceProfileEnrollmentProcessing = false
            voiceProfileEnrollmentRecording = nil
            let appError = AppError.speakerVerificationFailed(details: error.localizedDescription)
            DiagnosticLog.write("Voice profile enrollment Error: \(error.localizedDescription)")
            appState.lastError = appError
            setState(.failed(appError))
        }
    }

    func deleteVoiceProfile() {
        speakerProfileStore.deleteProfile()
        settings.isVoiceGateSpeakerMatchEnabled = false
        appState.lastDetail = "Voice profile removed."
        appState.notifyStatusChanged()
    }

    func deleteAllVoiceProfiles() {
        speakerProfileStore.deleteAllProfiles()
        settings.isVoiceGateSpeakerMatchEnabled = false
        appState.lastDetail = "All voice profiles removed."
        appState.notifyStatusChanged()
    }

    func installManagedSpeakerVerifierRuntime() async {
        await modelStore.installManagedSpeakerVerifierRuntime()
        appState.notifyStatusChanged()
    }

    func refreshPermissions() {
        permissionState.refresh(
            microphonePermission: microphonePermission,
            accessibilityPermission: accessibilityPermission,
            startupPermission: startupPermission
        )
    }

    func requestMicrophoneAccess() async {
        switch microphonePermission.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            _ = await microphonePermission.requestAccess()
        case .denied, .restricted:
            microphonePermission.openPrivacySettings()
        @unknown default:
            microphonePermission.openPrivacySettings()
        }

        refreshPermissions()
    }

    func availableMicrophones() -> [MicrophoneDevice] {
        MicrophoneDeviceCatalog.inputDevices()
    }

    func setSelectedMicrophoneDeviceID(_ deviceID: String?) {
        settings.selectedMicrophoneDeviceID = deviceID
    }

    func promptForAccessibilityAccess() {
        accessibilityPermission.promptForAccess()
        refreshPermissions()
    }

    func setStartsAtLogin(_ isEnabled: Bool) {
        do {
            try startupPermission.setStartsAtLogin(isEnabled)
            refreshPermissions()
        } catch {
            appState.lastError = .startupRegistrationFailed(details: error.localizedDescription)
            refreshPermissions()
        }
    }

    func selectASRModel(at url: URL) async {
        await modelStore.selectASRModel(at: url)
        configureASREngineFromSelectedModel()
    }

    func installManagedASRModel() async {
        await modelStore.installManagedASRModel()
        configureASREngineFromSelectedModel()
    }

    func clearASRModelSelection() {
        modelStore.clearASRSelection()
        pipeline.setASREngine(UnconfiguredASREngine())
    }

    func setPostProcessingEnabled(_ isEnabled: Bool) {
        settings.isPostProcessingEnabled = isEnabled
        configurePostProcessingEngineFromSelectedModel()
    }

    func togglePostProcessingEnabledFromHotkey() {
        setPostProcessingEnabled(!settings.isPostProcessingEnabled)
        appState.lastDetail = settings.isPostProcessingEnabled ? "Prime enabled." : "Prime disabled."
        appState.notifyStatusChanged()
    }

    func toggleVoiceGateSpeakerMatchFromHotkey() {
        if settings.isVoiceGateSpeakerMatchEnabled {
            settings.isVoiceGateSpeakerMatchEnabled = false
            appState.lastDetail = "Voice Gate verifier disabled."
            appState.notifyStatusChanged()
            return
        }

        guard speakerProfileStore.profile != nil else {
            appState.lastError = .speakerVerificationFailed(details: "Record a voice profile before enabling My Voice Only.")
            appState.lastDetail = "Voice profile is missing."
            appState.notifyStatusChanged()
            return
        }

        guard speakerProfileStore.profile?.modelID == SpeakerVerifierRuntimeLayout.modelID else {
            appState.lastError = .speakerVerificationFailed(details: "Re-enroll your voice profile before enabling My Voice Only.")
            appState.lastDetail = "Voice profile needs to be re-enrolled."
            appState.notifyStatusChanged()
            return
        }

        guard SpeakerVerifierRuntimeLayout.isInstalled() else {
            appState.lastError = .speakerVerificationFailed(details: "Install the speaker verifier before enabling My Voice Only.")
            appState.lastDetail = "Speaker verifier is not installed."
            appState.notifyStatusChanged()
            return
        }

        settings.isVoiceGateSpeakerMatchEnabled = true
        appState.lastDetail = "Voice Gate verifier enabled."
        appState.notifyStatusChanged()
    }

    func selectPostProcessingModel(at url: URL) async {
        await modelStore.selectPostProcessingModel(at: url)
        configurePostProcessingEngineFromSelectedModel()
    }

    func clearPostProcessingModelSelection() {
        modelStore.clearPostProcessingSelection()
        configurePostProcessingEngineFromSelectedModel()
    }

    func installManagedLlamaRuntime() async {
        await modelStore.installManagedLlamaRuntime()
        configurePostProcessingEngineFromSelectedModel()
    }

    func selectLlamaRuntime(at url: URL) async {
        await modelStore.selectLlamaRuntime(at: url)
        configurePostProcessingEngineFromSelectedModel()
    }

    func clearLlamaRuntimeSelection() {
        modelStore.clearLlamaRuntimeSelection()
        configurePostProcessingEngineFromSelectedModel()
    }

    func installManagedPostProcessingModel() async {
        await modelStore.installManagedPostProcessingModel()
        configurePostProcessingEngineFromSelectedModel()
    }

    private func configureASREngineFromSelectedModel() {
        guard
            let selection = modelStore.selectedASRModel,
            selection.validation.isValid
        else {
            pipeline.setASREngine(UnconfiguredASREngine())
            return
        }

        pipeline.setASREngine(
            FluidAudioParakeetEngine(
                modelURL: selection.url,
                computeMode: .all
            )
        )
        preloadASRModel()
    }

    private func preloadASRModel() {
        appState.lastDetail = "Loading ASR model..."
        DiagnosticLog.write("preloadASRModel started")
        appState.notifyStatusChanged()

        Task {
            do {
                try await pipeline.prepareASR()
                DiagnosticLog.write("preloadASRModel completed")
                appState.lastDetail = "ASR model ready."
                appState.notifyStatusChanged()
            } catch let error as AppError {
                DiagnosticLog.write("preloadASRModel AppError: \(error.userMessage) details=\(error.technicalDetails ?? "none")")
                appState.lastError = error
                appState.lastDetail = error.userMessage
                appState.notifyStatusChanged()
            } catch {
                DiagnosticLog.write("preloadASRModel Error: \(error.localizedDescription)")
                appState.lastError = .modelLoadFailed(details: error.localizedDescription)
                appState.lastDetail = "ASR model failed to load."
                appState.notifyStatusChanged()
            }
        }
    }

    private func configurePostProcessingEngineFromSelectedModel() {
        guard
            settings.isPostProcessingEnabled,
            let runtime = modelStore.selectedLlamaRuntime,
            runtime.validation.isValid,
            let selection = modelStore.selectedPostProcessingModel,
            selection.validation.isValid
        else {
            pipeline.setCleanupEngine(
                GemmaPrimeTextCleanupEngine(
                    textGenerationEngine: UnconfiguredLocalTextGenerationEngine()
                )
            )
            return
        }

        pipeline.setCleanupEngine(
            GemmaPrimeTextCleanupEngine(
                textGenerationEngine: Gemma4LocalTextGenerationEngine(
                    modelURL: selection.url,
                    runtimeURL: runtime.url
                )
            )
        )

        if settings.isPostProcessingEnabled {
            preloadPostProcessingModel()
        }
    }

    private func preloadPostProcessingModel() {
        appState.lastDetail = "Loading post-processing model..."
        DiagnosticLog.write("preloadPostProcessingModel started")
        appState.notifyStatusChanged()

        Task {
            do {
                try await pipeline.prepareCleanup()
                DiagnosticLog.write("preloadPostProcessingModel completed")
                appState.lastDetail = "Post-processing model ready."
                appState.notifyStatusChanged()
            } catch let error as AppError {
                DiagnosticLog.write("preloadPostProcessingModel AppError: \(error.userMessage) details=\(error.technicalDetails ?? "none")")
                appState.lastError = error
                appState.lastDetail = error.userMessage
                appState.notifyStatusChanged()
            } catch {
                DiagnosticLog.write("preloadPostProcessingModel Error: \(error.localizedDescription)")
                appState.lastError = .cleanupFailed(details: error.localizedDescription)
                appState.lastDetail = "Post-processing model failed to load."
                appState.notifyStatusChanged()
            }
        }
    }

    private func registerHotkeys() {
        guard hasStarted else {
            return
        }

        hotkeyService.unregister()

        do {
            try hotkeyService.register(hotkeyRegistrations(includeUtilityHotkeys: true))
            if case .hotkeyUnavailable = appState.lastError {
                appState.lastError = nil
            }
        } catch {
            DiagnosticLog.write("Hotkey registration failed with utility hotkeys: \(error.localizedDescription)")

            do {
                try hotkeyService.register(hotkeyRegistrations(includeUtilityHotkeys: false))
                appState.lastError = .hotkeyUnavailable(
                    details: "Prime or Voice Gate verifier hotkeys could not be registered, so EchoV kept the core dictation hotkeys active."
                )
            } catch {
                DiagnosticLog.write("Core hotkey registration failed: \(error.localizedDescription)")
                appState.lastError = .hotkeyUnavailable(details: error.localizedDescription)
            }
        }
    }

    private func hotkeyRegistrations(includeUtilityHotkeys: Bool) throws -> [HotkeyRegistration] {
        var configuredHotkeys: [(String, HotkeyBinding?)] = [
            ("Toggle", settings.toggleHotkey),
            ("Push-to-talk", settings.pushToTalkHotkey),
            ("Voice Gate", settings.voiceGateHotkey)
        ]

        if includeUtilityHotkeys {
            configuredHotkeys.append(contentsOf: [
                ("Prime", settings.primeToggleHotkey),
                ("Voice Gate verifier", settings.voiceGateVerifierToggleHotkey)
            ])
        }

        for firstIndex in configuredHotkeys.indices {
            let first = configuredHotkeys[firstIndex]
            guard let firstBinding = first.1 else {
                continue
            }

            for secondIndex in configuredHotkeys.index(after: firstIndex)..<configuredHotkeys.endIndex {
                let second = configuredHotkeys[secondIndex]
                if firstBinding == second.1 {
                    throw AppError.hotkeyUnavailable(details: "\(first.0) and \(second.0) cannot use the same hotkey.")
                }
            }
        }

        if
            let toggleHotkey = settings.toggleHotkey,
            let pushToTalkHotkey = settings.pushToTalkHotkey,
            toggleHotkey == pushToTalkHotkey
        {
            throw AppError.hotkeyUnavailable(details: "Toggle and push-to-talk cannot use the same hotkey.")
        }

        if
            let toggleHotkey = settings.toggleHotkey,
            let voiceGateHotkey = settings.voiceGateHotkey,
            toggleHotkey == voiceGateHotkey
        {
            throw AppError.hotkeyUnavailable(details: "Toggle and Voice Gate cannot use the same hotkey.")
        }

        if
            let pushToTalkHotkey = settings.pushToTalkHotkey,
            let voiceGateHotkey = settings.voiceGateHotkey,
            pushToTalkHotkey == voiceGateHotkey
        {
            throw AppError.hotkeyUnavailable(details: "Push-to-talk and Voice Gate cannot use the same hotkey.")
        }

        var registrations: [HotkeyRegistration] = []

        if let toggleHotkey = settings.toggleHotkey {
            registrations.append(
                HotkeyRegistration(
                    id: HotkeyID.toggle,
                    binding: toggleHotkey,
                    onPressed: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.handleToggleHotkey()
                        }
                    },
                    onReleased: nil
                )
            )
        }

        if let pushToTalkHotkey = settings.pushToTalkHotkey {
            registrations.append(
                HotkeyRegistration(
                    id: HotkeyID.pushToTalk,
                    binding: pushToTalkHotkey,
                    onPressed: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.handlePushToTalkPressed()
                        }
                    },
                    onReleased: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.handlePushToTalkReleased()
                        }
                    }
                )
            )
        }

        if let voiceGateHotkey = settings.voiceGateHotkey {
            registrations.append(
                HotkeyRegistration(
                    id: HotkeyID.voiceGate,
                    binding: voiceGateHotkey,
                    onPressed: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.handleVoiceGateHotkey()
                        }
                    },
                    onReleased: nil
                )
            )
        }

        if includeUtilityHotkeys, let primeToggleHotkey = settings.primeToggleHotkey {
            registrations.append(
                HotkeyRegistration(
                    id: HotkeyID.primeToggle,
                    binding: primeToggleHotkey,
                    onPressed: { [weak self] in
                        Task { @MainActor [weak self] in
                            self?.togglePostProcessingEnabledFromHotkey()
                        }
                    },
                    onReleased: nil
                )
            )
        }

        if includeUtilityHotkeys, let voiceGateVerifierToggleHotkey = settings.voiceGateVerifierToggleHotkey {
            registrations.append(
                HotkeyRegistration(
                    id: HotkeyID.voiceGateVerifierToggle,
                    binding: voiceGateVerifierToggleHotkey,
                    onPressed: { [weak self] in
                        Task { @MainActor [weak self] in
                            self?.toggleVoiceGateSpeakerMatchFromHotkey()
                        }
                    },
                    onReleased: nil
                )
            )
        }

        return registrations
    }

    private func isHotkeyAvailable(
        _ binding: HotkeyBinding?,
        excluding excludedKeyPath: KeyPath<AppSettings, HotkeyBinding?>
    ) -> Bool {
        guard let binding else {
            return true
        }

        let bindings: [KeyPath<AppSettings, HotkeyBinding?>] = [
            \.toggleHotkey,
            \.pushToTalkHotkey,
            \.voiceGateHotkey,
            \.primeToggleHotkey,
            \.voiceGateVerifierToggleHotkey
        ]

        return bindings.allSatisfy { keyPath in
            keyPath == excludedKeyPath || settings[keyPath: keyPath] != binding
        }
    }

    private func handleToggleHotkey() async {
        switch recordingTrigger {
        case nil:
            guard appState.state.canStartRecording else {
                return
            }

            recordingTrigger = .toggle
            await pipeline.startRecording()

            if !appState.state.isRecording {
                recordingTrigger = nil
            }
        case .toggle:
            guard appState.state.isRecording else {
                recordingTrigger = nil
                return
            }

            await pipeline.stopTranscribeAndInsert()
            recordingTrigger = nil
        case .pushToTalk:
            return
        case .voiceGate:
            return
        }
    }

    private func handlePushToTalkPressed() async {
        guard recordingTrigger == nil, appState.state.canStartRecording else {
            return
        }

        recordingTrigger = .pushToTalk

        switch await prepareMicrophoneForPushToTalk() {
        case .ready:
            break
        case .retryNeeded:
            if recordingTrigger == .pushToTalk {
                recordingTrigger = nil
            }
            return
        case .failed:
            return
        }

        await pipeline.startRecording()

        guard appState.state.isRecording else {
            recordingTrigger = nil
            return
        }

        guard recordingTrigger == .pushToTalk else {
            await pipeline.stopTranscribeAndInsert()
            return
        }
    }

    private func handlePushToTalkReleased() async {
        guard recordingTrigger == .pushToTalk else {
            return
        }

        guard appState.state.isRecording else {
            recordingTrigger = nil
            return
        }

        await pipeline.stopTranscribeAndInsert()
        recordingTrigger = nil
    }

    private func handleVoiceGateHotkey() async {
        if isVoiceGateArmed {
            disarmVoiceGate()
            return
        }

        guard recordingTrigger == nil, appState.state.canStartRecording else {
            return
        }

        isVoiceGateArmed = true
        recordingTrigger = .voiceGate
        await startVoiceGateListening()
    }

    private enum PushToTalkMicrophonePreparation {
        case ready
        case retryNeeded
        case failed
    }

    private func prepareMicrophoneForPushToTalk() async -> PushToTalkMicrophonePreparation {
        switch microphonePermission.authorizationStatus() {
        case .authorized:
            return .ready
        case .notDetermined:
            let granted = await microphonePermission.requestAccess()
            refreshPermissions()

            guard granted else {
                failMicrophonePermission()
                recordingTrigger = nil
                return .failed
            }

            appState.lastError = nil
            appState.lastDetail = "Microphone access granted. Hold push-to-talk again to record."
            setState(.cancelled)
            return .retryNeeded
        case .denied, .restricted:
            refreshPermissions()
            failMicrophonePermission()
            recordingTrigger = nil
            return .failed
        @unknown default:
            refreshPermissions()
            failMicrophonePermission()
            recordingTrigger = nil
            return .failed
        }
    }

    private func failMicrophonePermission() {
        appState.lastError = .microphonePermissionDenied
        setState(.failed(.microphonePermissionDenied))
    }

    private func startVoiceGateListening() async {
        guard isVoiceGateArmed else {
            return
        }

        appState.lastError = nil
        appState.lastDetail = "Voice Gate is armed. Speak when ready."
        setState(.listening)

        do {
            try await voiceGateCapture.start(
                configuration: VoiceGateCaptureConfiguration(
                    silenceTimeout: settings.voiceGateSilenceTimeout,
                    sensitivity: settings.voiceGateSensitivity
                ),
                onSpeechStarted: { [weak self] startedAt in
                    guard let self, self.isVoiceGateArmed else {
                        return
                    }

                    self.appState.lastDetail = "Speech detected. Waiting for silence to transcribe."
                    self.setState(.voiceGateRecording(startedAt: startedAt))
                },
                onUtteranceEnded: { [weak self] recordedAudio in
                    Task { @MainActor [weak self] in
                        await self?.handleVoiceGateUtterance(recordedAudio)
                    }
                },
                onError: { [weak self] error in
                    guard let self else {
                        return
                    }

                    self.recordingTrigger = nil
                    self.isVoiceGateArmed = false
                    self.appState.lastError = error
                    self.setState(.failed(error))
                }
            )
        } catch let error as AppError {
            recordingTrigger = nil
            isVoiceGateArmed = false
            appState.lastError = error
            setState(.failed(error))
        } catch {
            recordingTrigger = nil
            isVoiceGateArmed = false
            let appError = AppError.recordingFailed(details: error.localizedDescription)
            appState.lastError = appError
            setState(.failed(appError))
        }
    }

    private func handleVoiceGateUtterance(_ recordedAudio: RecordedAudio) async {
        guard isVoiceGateArmed else {
            temporaryAudioStore.delete([recordedAudio.fileURL])
            return
        }

        if settings.isVoiceGateSpeakerMatchEnabled {
            do {
                let isAccepted = try await verifyVoiceGateSpeaker(recordedAudio)
                guard isAccepted else {
                    temporaryAudioStore.delete([recordedAudio.fileURL])

                    guard isVoiceGateArmed else {
                        recordingTrigger = nil
                        return
                    }

                    await startVoiceGateListening()
                    return
                }
            } catch let error as AppError {
                temporaryAudioStore.delete([recordedAudio.fileURL])
                recordingTrigger = nil
                isVoiceGateArmed = false
                appState.lastError = error
                setState(.failed(error))
                return
            } catch {
                temporaryAudioStore.delete([recordedAudio.fileURL])
                recordingTrigger = nil
                isVoiceGateArmed = false
                let appError = AppError.speakerVerificationFailed(details: error.localizedDescription)
                appState.lastError = appError
                setState(.failed(appError))
                return
            }
        }

        await pipeline.transcribeAndInsert(recordedAudio)

        guard isVoiceGateArmed else {
            recordingTrigger = nil
            return
        }

        await startVoiceGateListening()
    }

    private func verifyVoiceGateSpeaker(_ recordedAudio: RecordedAudio) async throws -> Bool {
        guard let profile = speakerProfileStore.profile else {
            throw AppError.speakerVerificationFailed(details: "Turn off My Voice Only or record a voice profile first.")
        }

        let threshold = settings.voiceGateSpeakerMatchStrictness.minimumSimilarity
        let mode = settings.voiceGateSpeakerVerificationMode
        appState.lastDetail = mode == .continuous ? "Checking voice across the command..." : "Checking voice at the start..."
        setState(.transcribing(status: "Checking voice..."))

        let windows = try verificationWindows(for: recordedAudio, mode: mode)
        defer {
            temporaryAudioStore.delete(windows.map(\.fileURL))
        }

        guard !windows.isEmpty else {
            throw AppError.speakerVerificationFailed(details: "Voice Gate did not create audio windows for speaker verification.")
        }

        var acceptedSimilarities: [Double] = []
        for (index, window) in windows.enumerated() {
            if windows.count > 1 {
                appState.lastDetail = "Checking voice window \(index + 1) of \(windows.count)..."
                setState(.transcribing(status: "Checking voice \(index + 1)/\(windows.count)..."))
            }

            let result = try await speakerVerificationService.score(
                audioURL: window.fileURL,
                profile: profile,
                threshold: threshold
            )

            guard result.isMatch else {
                appState.lastDetail = mode == .continuous
                    ? "Voice changed or overlapped. Command ignored."
                    : "Different voice ignored."
                setState(.cancelled)
                return false
            }

            acceptedSimilarities.append(result.similarity)
        }

        let minimumSimilarity = acceptedSimilarities.min() ?? 0
        appState.lastDetail = mode == .continuous
            ? String(format: "Voice matched across command %.0f%% minimum. Transcribing...", minimumSimilarity * 100)
            : String(format: "Voice matched %.0f%%. Transcribing...", minimumSimilarity * 100)
        return true
    }

    private func verificationWindows(
        for recordedAudio: RecordedAudio,
        mode: VoiceGateSpeakerVerificationMode
    ) throws -> [AudioWindow] {
        switch mode {
        case .startOnly:
            return try voiceGateVerificationWindows.extractLeadingWindow(from: recordedAudio.fileURL)
        case .continuous:
            return try voiceGateVerificationWindows.extractOverlappingWindows(from: recordedAudio.fileURL)
        }
    }

    private func disarmVoiceGate() {
        isVoiceGateArmed = false
        voiceGateCapture.stop()

        switch appState.state {
        case .listening, .voiceGateRecording:
            setState(.cancelled)
        case .idle, .recording, .transcribing, .cleaning, .inserting, .completed, .failed, .cancelled:
            break
        }

        recordingTrigger = nil
        appState.lastDetail = "Voice Gate is muted."
        appState.notifyStatusChanged()
    }

    private func setState(_ state: DictationState) {
        appState.state = state
        appState.notifyStatusChanged()
    }
}

private extension DictationState {
    var canStartRecording: Bool {
        switch self {
        case .idle, .completed, .failed, .cancelled:
            true
        case .listening, .recording, .voiceGateRecording, .transcribing, .cleaning, .inserting:
            false
        }
    }

    var isRecording: Bool {
        switch self {
        case .recording, .voiceGateRecording:
            return true
        case .idle, .listening, .transcribing, .cleaning, .inserting, .completed, .failed, .cancelled:
            return false
        }
    }
}
