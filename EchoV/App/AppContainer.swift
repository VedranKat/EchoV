import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {
    private static let liveSubtitlePrimeIdleShutdownDelaySeconds: TimeInterval = 120
    private static let localAssistantContextWindowTokens = 4_096
    private static let voiceAssistantMaximumRecentMessages = 10

    private enum HotkeyID {
        static let toggle = UInt32(1)
        static let pushToTalk = UInt32(2)
        static let voiceGate = UInt32(3)
        static let primeToggle = UInt32(4)
        static let voiceGateVerifierToggle = UInt32(5)
        static let voiceModeActivation = UInt32(6)
        static let voiceModeTextActivation = UInt32(7)
        static let stop = UInt32(8)
        static let liveSubtitles = UInt32(9)
    }

    private enum RecordingTrigger {
        case toggle
        case pushToTalk
        case voiceGate
        case voiceMode
        case liveSubtitles
        case voiceProfileEnrollment
    }

    private struct LocalTextGenerationEngineKey: Equatable {
        let runtimePath: String
        let modelPath: String
        let modelDefinitionID: String

        init(runtime: LlamaRuntimeSelection, model: PostProcessingModelSelection) {
            runtimePath = runtime.url.standardizedFileURL.path
            modelPath = model.url.standardizedFileURL.path
            modelDefinitionID = model.modelDefinition.id
        }
    }

    private enum VoiceGuardWorkflow {
        case voiceGate
        case voiceModeCommand
        case voiceModeRequest

        var emptyWindowsError: String {
            switch self {
            case .voiceGate:
                "Hands-free did not create audio windows for speaker verification."
            case .voiceModeCommand:
                "Assistant did not create command audio windows for speaker verification."
            case .voiceModeRequest:
                "Assistant did not create request audio windows for speaker verification."
            }
        }

        var matchedContinuousDetail: String {
            switch self {
            case .voiceGate:
                "Voice matched across command %.0f%% minimum. Transcribing..."
            case .voiceModeCommand:
                "Voice matched across command %.0f%% minimum."
            case .voiceModeRequest:
                "Voice matched across request %.0f%% minimum. Transcribing..."
            }
        }

        var matchedStartDetail: String {
            switch self {
            case .voiceGate:
                "Voice matched %.0f%%. Transcribing..."
            case .voiceModeCommand:
                "Voice matched %.0f%%."
            case .voiceModeRequest:
                "Voice matched %.0f%%. Transcribing..."
            }
        }

        var checkingContinuousDetail: String {
            switch self {
            case .voiceGate:
                "Checking voice across the utterance..."
            case .voiceModeCommand:
                "Checking voice across the command..."
            case .voiceModeRequest:
                "Checking voice across the request..."
            }
        }

        var checkingStartDetail: String {
            switch self {
            case .voiceGate, .voiceModeCommand, .voiceModeRequest:
                "Checking voice at the start..."
            }
        }

        var continuousMismatchDetail: String {
            switch self {
            case .voiceGate:
                "Voice changed or overlapped. Utterance ignored."
            case .voiceModeCommand:
                "Voice changed or overlapped. Command ignored."
            case .voiceModeRequest:
                "Voice changed or overlapped. Request ignored."
            }
        }
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
    let textResponseSessions: TextResponseSessionStore
    let liveSubtitles: LiveSubtitleStore

    private let hotkeyService: any HotkeyService
    private let voiceGateCapture: VoiceActivatedAudioCapture
    private let voiceModeController: VoiceModeController
    private let liveSubtitleController: LiveSubtitleController
    private let speakerVerificationService: any SpeakerVerificationService
    private let voiceGateVerificationWindows: AudioWindowExtractor
    private let voiceProfileEnrollmentRecorder: any AudioRecorder
    private let selectedTextCapture: SelectedTextCaptureService
    private let textResponseSessionNotifier: TextResponseSessionNotifier
    private let assistantConfirmationSounds: AssistantConfirmationSoundService
    private var localTextGenerationEngine: any LocalTextGenerationEngine
    private var localTextGenerationEngineKey: LocalTextGenerationEngineKey?
    private var liveSubtitleTextGenerationEngineKey: LocalTextGenerationEngineKey?
    private var localTextGenerationIdleShutdownTask: Task<Void, Never>?
    private var localTextGenerationConfigurationGeneration = 0
    private var hasStarted = false
    private var recordingTrigger: RecordingTrigger?
    private var isVoiceGateArmed = false
    private var voiceProfileEnrollmentRecording: RecordedAudio?
    private var textResponseGenerationTasks: [UUID: Task<String?, Never>] = [:]
    private var promptPreviewContinuation: CheckedContinuation<String?, Never>?
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
        textResponseSessions: TextResponseSessionStore,
        liveSubtitles: LiveSubtitleStore,
        hotkeyService: any HotkeyService,
        voiceGateCapture: VoiceActivatedAudioCapture,
        voiceModeController: VoiceModeController,
        liveSubtitleController: LiveSubtitleController,
        speakerVerificationService: any SpeakerVerificationService,
        voiceGateVerificationWindows: AudioWindowExtractor,
        voiceProfileEnrollmentRecorder: any AudioRecorder,
        selectedTextCapture: SelectedTextCaptureService,
        textResponseSessionNotifier: TextResponseSessionNotifier,
        assistantConfirmationSounds: AssistantConfirmationSoundService,
        localTextGenerationEngine: any LocalTextGenerationEngine
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
        self.textResponseSessions = textResponseSessions
        self.liveSubtitles = liveSubtitles
        self.hotkeyService = hotkeyService
        self.voiceGateCapture = voiceGateCapture
        self.voiceModeController = voiceModeController
        self.liveSubtitleController = liveSubtitleController
        self.speakerVerificationService = speakerVerificationService
        self.voiceGateVerificationWindows = voiceGateVerificationWindows
        self.voiceProfileEnrollmentRecorder = voiceProfileEnrollmentRecorder
        self.selectedTextCapture = selectedTextCapture
        self.textResponseSessionNotifier = textResponseSessionNotifier
        self.assistantConfirmationSounds = assistantConfirmationSounds
        self.localTextGenerationEngine = localTextGenerationEngine
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
        let textResponseSessions = TextResponseSessionStore()
        let textResponseSessionNotifier = TextResponseSessionNotifier()
        let assistantConfirmationSounds = AssistantConfirmationSoundService()
        let liveSubtitles = LiveSubtitleStore()

        let pipeline = DictationPipeline(
            appState: appState,
            recorder: AVFoundationAudioRecorder(
                microphonePermission: microphonePermission,
                selectedMicrophoneDeviceID: { settings.selectedMicrophoneDeviceID },
                isAppleVoiceProcessingEnabled: { settings.isDictationAppleVoiceProcessingEnabled }
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
            cleanupContextProvider: {
                Self.makeCleanupContext(settings: settings)
            },
            onStateChanged: { appState.notifyStatusChanged() }
        )

        let localTextGenerationEngine = UnconfiguredLocalTextGenerationEngine()
        let liveSubtitleController = LiveSubtitleController(
            store: liveSubtitles,
            capture: LiveSubtitleAudioCapture(microphonePermission: microphonePermission),
            asrEngine: UnconfiguredASREngine(),
            textGenerationEngine: localTextGenerationEngine,
            selectedAudioDeviceID: { settings.selectedLiveSubtitleAudioDeviceID },
            chunkConfiguration: { settings.liveSubtitleChunkConfiguration },
            mode: { settings.liveSubtitleMode },
            targetLanguage: { settings.liveSubtitleTargetLanguage },
            showsRawWhileProcessing: { settings.liveSubtitleShowsRawWhileProcessing },
            holdSeconds: { settings.liveSubtitleHoldSeconds }
        )
        let voiceModeController = VoiceModeController(
            appState: appState,
            capture: VoiceActivatedAudioCapture(
                microphonePermission: microphonePermission,
                selectedMicrophoneDeviceID: { settings.selectedMicrophoneDeviceID },
                isAppleVoiceProcessingEnabled: { settings.isDictationAppleVoiceProcessingEnabled }
            ),
            pipeline: pipeline,
            textGenerationEngine: localTextGenerationEngine,
            speechOutput: KokoroSpeechOutputService(),
            promptEndingPolicy: {
                VoiceModePromptEndingPolicy(
                    mode: settings.voiceModePromptEndingMode,
                    fixedPauseSeconds: settings.voiceModeResponsePauseSeconds,
                    adaptivePausePreset: settings.voiceModeAdaptivePausePreset,
                    customAdaptiveFastPauseSeconds: settings.voiceModeAdaptiveFastPauseSeconds,
                    customAdaptiveMinimumSpeechSeconds: settings.voiceModeAdaptiveMinimumSpeechSeconds,
                    stopPhrase: settings.voiceModeStopPhrase
                )
            },
            noSpeechTimeoutSeconds: { settings.voiceModeNoSpeechTimeoutSeconds },
            speechVoiceIdentifier: { settings.voiceModeKokoroVoiceIdentifier },
            speechSpeed: { settings.voiceModeKokoroSpeed },
            onStopped: {},
            onStateChanged: { appState.notifyStatusChanged() }
        )

        let container = AppContainer(
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
            textResponseSessions: textResponseSessions,
            liveSubtitles: liveSubtitles,
            hotkeyService: CarbonHotkeyService(),
            voiceGateCapture: VoiceActivatedAudioCapture(
                microphonePermission: microphonePermission,
                selectedMicrophoneDeviceID: { settings.selectedMicrophoneDeviceID },
                isAppleVoiceProcessingEnabled: { settings.isDictationAppleVoiceProcessingEnabled }
            ),
            voiceModeController: voiceModeController,
            liveSubtitleController: liveSubtitleController,
            speakerVerificationService: ONNXSpeakerVerificationService(),
            voiceGateVerificationWindows: AudioWindowExtractor(),
            voiceProfileEnrollmentRecorder: AVFoundationAudioRecorder(
                microphonePermission: microphonePermission,
                minimumDuration: 3,
                selectedMicrophoneDeviceID: { settings.selectedMicrophoneDeviceID },
                isAppleVoiceProcessingEnabled: { settings.isDictationAppleVoiceProcessingEnabled }
            ),
            selectedTextCapture: SelectedTextCaptureService(accessibilityPermission: accessibilityPermission),
            textResponseSessionNotifier: textResponseSessionNotifier,
            assistantConfirmationSounds: assistantConfirmationSounds,
            localTextGenerationEngine: localTextGenerationEngine
        )
        voiceModeController.setOnStopped { [weak container] in
            container?.recordingTrigger = nil
        }
        liveSubtitleController.setOnStopped { [weak container] in
            guard let container, container.recordingTrigger == .liveSubtitles else {
                return
            }
            container.recordingTrigger = nil
            container.settings.isLiveSubtitlesEnabled = false
        }
        voiceModeController.setOnAssistantSessionRequest { [weak container] command, userText, selectedText in
            guard let container else {
                throw AppError.voiceModeResponseFailed(details: "Assistant session storage is unavailable.")
            }

            return try await container.performVoiceModeAssistantTurn(
                command: command,
                userText: userText,
                selectedText: selectedText
            )
        }
        voiceModeController.setOnCleanUpSelection { [weak container] in
            await container?.cleanUpSelectedText() ?? false
        }
        voiceModeController.setSelectedTextProvider { [weak container] in
            await container?.captureSelectedText()
        }
        voiceModeController.setPromptPreview { [weak container] command, promptText, includesSelectionContext in
            await container?.reviewVoiceModePrompt(
                command: command,
                promptText: promptText,
                includesSelectionContext: includesSelectionContext
            )
        }
        voiceModeController.setConfirmationCuePlayer { [weak container] command in
            await container?.playAssistantConfirmationCue(for: command)
        }
        voiceModeController.setResponseBackendValidationError { [weak container] in
            container?.voiceModeResponseBackendValidationError()
        }
        voiceModeController.setVoiceGuardVerifiers(
            commandVerifier: { [weak container] recordedAudio in
                try await container?.verifyVoiceModeCommandSpeaker(recordedAudio) ?? true
            },
            requestVerifier: { [weak container] recordedAudio in
                try await container?.verifyVoiceModeRequestSpeaker(recordedAudio) ?? true
            }
        )
        return container
    }

    func start() {
        hasStarted = true
        refreshPermissions()

        Task {
            await historyStore.load()
            await modelStore.restoreSelection()
            if !SpeakerVerifierRuntimeLayout.isInstalled()
                || speakerProfileStore.profile?.modelID != SpeakerVerifierRuntimeLayout.modelID {
                settings.isVoiceGuardEnabled = false
            }
            configureASREngineFromSelectedModel()
            configurePostProcessingEngineFromSelectedModel()
            if settings.isLiveSubtitlesEnabled {
                await startLiveSubtitlesIfPossible()
            }
            if settings.isVoiceModeEnabled {
                await startVoiceModeIfPossible()
            }
        }

        registerHotkeys()
    }

    func stop() async {
        hasStarted = false
        hotkeyService.unregister()
        voiceGateCapture.stop()
        voiceModeController.stop()
        liveSubtitleController.stop(notify: false)
        if isVoiceProfileEnrollmentRecording {
            _ = try? await voiceProfileEnrollmentRecorder.stop()
            isVoiceProfileEnrollmentRecording = false
            voiceProfileEnrollmentRecording = nil
        }
        localTextGenerationIdleShutdownTask?.cancel()
        localTextGenerationIdleShutdownTask = nil
        await pipeline.shutdownCleanupEngine()
        await localTextGenerationEngine.shutdown()
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
            appState.lastError = .hotkeyUnavailable(details: "Toggle and Hands-free cannot use the same hotkey.")
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
            appState.lastError = .hotkeyUnavailable(details: "Push-to-talk and Hands-free cannot use the same hotkey.")
            return
        }

        settings.pushToTalkHotkey = binding
        registerHotkeys()
    }

    func setVoiceGateHotkey(_ binding: HotkeyBinding?) {
        guard isHotkeyAvailable(binding, excluding: \.voiceGateHotkey) else {
            appState.lastError = .hotkeyUnavailable(details: "Hands-free cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        guard binding == nil || binding != settings.toggleHotkey else {
            appState.lastError = .hotkeyUnavailable(details: "Hands-free and toggle cannot use the same hotkey.")
            return
        }

        guard binding == nil || binding != settings.pushToTalkHotkey else {
            appState.lastError = .hotkeyUnavailable(details: "Hands-free and push-to-talk cannot use the same hotkey.")
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
            appState.lastError = .hotkeyUnavailable(details: "Trusted Voice cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        settings.voiceGateVerifierToggleHotkey = binding
        registerHotkeys()
    }

    func setVoiceModeActivationHotkey(_ binding: HotkeyBinding?) {
        guard isHotkeyAvailable(binding, excluding: \.voiceModeActivationHotkey) else {
            appState.lastError = .hotkeyUnavailable(details: "Assistant cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        settings.voiceModeActivationHotkey = binding
        registerHotkeys()
    }

    func setVoiceModeTextActivationHotkey(_ binding: HotkeyBinding?) {
        guard isHotkeyAvailable(binding, excluding: \.voiceModeTextActivationHotkey) else {
            appState.lastError = .hotkeyUnavailable(details: "Assistant text cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        settings.voiceModeTextActivationHotkey = binding
        registerHotkeys()
    }

    func setLiveSubtitleHotkey(_ binding: HotkeyBinding?) {
        guard isHotkeyAvailable(binding, excluding: \.liveSubtitleHotkey) else {
            appState.lastError = .hotkeyUnavailable(details: "Live Subtitles cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        settings.liveSubtitleHotkey = binding
        registerHotkeys()
    }

    func setStopHotkey(_ binding: HotkeyBinding?) {
        guard isHotkeyAvailable(binding, excluding: \.stopHotkey) else {
            appState.lastError = .hotkeyUnavailable(details: "Stop EchoV cannot use the same hotkey as another EchoV shortcut.")
            return
        }

        settings.stopHotkey = binding
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

        guard makeVoiceModeYieldToManualRecordingIfNeeded(),
              recordingTrigger == nil,
              appState.state.canStartRecording
        else {
            appState.lastError = .recordingFailed(details: "Stop the current recording before enrolling a voice profile.")
            return
        }

        recordingTrigger = .voiceProfileEnrollment

        do {
            voiceProfileEnrollmentRecording = try await voiceProfileEnrollmentRecorder.start()
            isVoiceProfileEnrollmentRecording = true
            appState.lastError = nil
            appState.lastDetail = "Recording your voice profile. Speak naturally for at least a few seconds."
            setState(.recording(startedAt: Date()))
        } catch let error as AppError {
            recordingTrigger = nil
            appState.lastError = error
            setState(.failed(error))
            await startVoiceModeAfterCurrentTaskIfNeeded()
        } catch {
            recordingTrigger = nil
            let appError = AppError.recordingFailed(details: error.localizedDescription)
            appState.lastError = appError
            setState(.failed(appError))
            await startVoiceModeAfterCurrentTaskIfNeeded()
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
            recordingTrigger = nil
            appState.lastError = nil
            appState.lastDetail = "Voice profile enrolled."
            setState(.completed(Transcript(text: "Voice profile enrolled.", segments: [])))
            await startVoiceModeAfterCurrentTaskIfNeeded()
        } catch let error as AppError {
            isVoiceProfileEnrollmentRecording = false
            isVoiceProfileEnrollmentProcessing = false
            voiceProfileEnrollmentRecording = nil
            recordingTrigger = nil
            DiagnosticLog.write("Voice profile enrollment AppError: \(error.userMessage) details=\(error.technicalDetails ?? "none")")
            appState.lastError = error
            setState(.failed(error))
            await startVoiceModeAfterCurrentTaskIfNeeded()
        } catch {
            isVoiceProfileEnrollmentRecording = false
            isVoiceProfileEnrollmentProcessing = false
            voiceProfileEnrollmentRecording = nil
            recordingTrigger = nil
            let appError = AppError.speakerVerificationFailed(details: error.localizedDescription)
            DiagnosticLog.write("Voice profile enrollment Error: \(error.localizedDescription)")
            appState.lastError = appError
            setState(.failed(appError))
            await startVoiceModeAfterCurrentTaskIfNeeded()
        }
    }

    func deleteVoiceProfile() {
        speakerProfileStore.deleteProfile()
        settings.isVoiceGuardEnabled = false
        appState.lastDetail = "Voice profile removed."
        appState.notifyStatusChanged()
    }

    func deleteAllVoiceProfiles() {
        speakerProfileStore.deleteAllProfiles()
        settings.isVoiceGuardEnabled = false
        appState.lastDetail = "All voice profiles removed."
        appState.notifyStatusChanged()
    }

    func installManagedSpeakerVerifierRuntime() async {
        await modelStore.installManagedSpeakerVerifierRuntime()
        appState.notifyStatusChanged()
    }

    func refreshPermissions(notifyOnChange: Bool = true) {
        permissionState.refresh(
            microphonePermission: microphonePermission,
            accessibilityPermission: accessibilityPermission,
            startupPermission: startupPermission,
            notifyOnChange: notifyOnChange
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
        guard !isEnabled || canEnablePostProcessing else {
            settings.isPostProcessingEnabled = false
            configurePostProcessingEngineFromSelectedModel()
            appState.lastError = .cleanupModelNotConfigured
            appState.lastDetail = postProcessingUnavailableDetail
            appState.notifyStatusChanged()
            return
        }

        settings.isPostProcessingEnabled = isEnabled
        configurePostProcessingEngineFromSelectedModel()
    }

    var canEnablePostProcessing: Bool {
        modelStore.selectedLlamaRuntime?.validation.isValid == true
            && modelStore.isSelectedPostProcessingModelReady
    }

    var postProcessingUnavailableDetail: String {
        if modelStore.selectedLlamaRuntime?.validation.isValid != true {
            return "Install the llama.cpp runtime before enabling Prime."
        }

        if !modelStore.isSelectedPostProcessingModelReady {
            return "Download \(modelStore.selectedPostProcessingModelDefinition.displayName) before enabling Prime."
        }

        return "Prime is ready."
    }

    func setPrimeAppAwareFormattingEnabled(_ isEnabled: Bool) {
        settings.isPrimeAppAwareFormattingEnabled = isEnabled
    }

    func setPrimeCustomVocabularyEnabled(_ isEnabled: Bool) {
        settings.isPrimeCustomVocabularyEnabled = isEnabled
    }

    func addPrimeVocabularyEntry(
        term: String,
        aliases: [String],
        aggressiveness: PrimeVocabularyAggressiveness
    ) -> Bool {
        guard PrimeVocabularyEntry.validationFailure(
            term: term,
            aliasCandidates: aliases,
            existingEntries: settings.primeVocabularyEntries
        ) == nil else {
            return false
        }
        let entry = PrimeVocabularyEntry(
            term: term,
            aliases: aliases,
            aggressiveness: aggressiveness
        )
        guard entry.isValid else {
            return false
        }

        var entries = settings.primeVocabularyEntries
        entries.append(entry)
        let normalizedEntries = PrimeVocabularyEntry.normalizedEntries(entries)
        guard normalizedEntries.contains(where: { $0.id == entry.id }) else {
            return false
        }

        settings.primeVocabularyEntries = normalizedEntries
        return true
    }

    func removePrimeVocabularyEntry(id: UUID) {
        settings.primeVocabularyEntries = settings.primeVocabularyEntries.filter { $0.id != id }
    }

    func setPrimeVocabularyEntryEnabled(id: UUID, isEnabled: Bool) {
        updatePrimeVocabularyEntry(id: id) { entry in
            entry.isEnabled = isEnabled
        }
    }

    func setPrimeVocabularyEntryAggressiveness(id: UUID, aggressiveness: PrimeVocabularyAggressiveness) {
        updatePrimeVocabularyEntry(id: id) { entry in
            entry.aggressiveness = aggressiveness
        }
    }

    func setPrimeVocabularyEntryAliases(id: UUID, aliases: [String]) -> Bool {
        var entries = settings.primeVocabularyEntries
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return false
        }

        let existingEntries = entries.filter { $0.id != id }
        guard PrimeVocabularyEntry.validationFailure(
            term: entries[index].term,
            aliasCandidates: aliases,
            existingEntries: existingEntries
        ) == nil else {
            return false
        }

        entries[index].aliases = PrimeVocabularyEntry.normalizedAliases(aliases)
        settings.primeVocabularyEntries = PrimeVocabularyEntry.normalizedEntries(entries)
        return true
    }

    private func updatePrimeVocabularyEntry(
        id: UUID,
        transform: (inout PrimeVocabularyEntry) -> Void
    ) {
        var entries = settings.primeVocabularyEntries
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            return
        }

        transform(&entries[index])
        settings.primeVocabularyEntries = PrimeVocabularyEntry.normalizedEntries(entries)
    }

    func setVoiceModeEnabled(_ isEnabled: Bool) {
        settings.isVoiceModeEnabled = isEnabled

        if isEnabled {
            configurePostProcessingEngineFromSelectedModel()
            Task {
                await startVoiceModeIfPossible()
            }
        } else {
            voiceModeController.stop()
            configurePostProcessingEngineFromSelectedModel()
        }
    }

    func setVoiceModeResponseBackend(_ backend: VoiceModeResponseBackend) {
        settings.voiceModeResponseBackend = backend
        configurePostProcessingEngineFromSelectedModel()
    }

    func setVoiceModeHUDEnabled(_ isEnabled: Bool) {
        settings.isVoiceModeHUDEnabled = isEnabled
        appState.notifyStatusChanged()
    }

    func setLiveSubtitlesEnabled(_ isEnabled: Bool) {
        settings.isLiveSubtitlesEnabled = isEnabled
        configurePostProcessingEngineFromSelectedModel()

        if isEnabled {
            Task {
                await self.startLiveSubtitlesIfPossible()
            }
        } else {
            liveSubtitleController.stop()
            if recordingTrigger == .liveSubtitles {
                recordingTrigger = nil
            }
            if settings.isVoiceModeEnabled {
                Task {
                    await self.startVoiceModeIfPossible()
                }
            }
        }
    }

    func setLiveSubtitleMode(_ mode: LiveSubtitleMode) {
        settings.liveSubtitleMode = mode
        configurePostProcessingEngineFromSelectedModel()
    }

    func setLiveSubtitleAudioDeviceID(_ deviceID: String?) {
        settings.selectedLiveSubtitleAudioDeviceID = validatedAudioDeviceID(deviceID)
        if liveSubtitles.isRunning {
            recordingTrigger = nil
            liveSubtitleController.stop()
            settings.isLiveSubtitlesEnabled = true
            Task {
                await self.startLiveSubtitlesIfPossible()
            }
        }
    }

    func availableLiveSubtitleAudioDevices() -> [MicrophoneDevice] {
        MicrophoneDeviceCatalog.inputDevices()
    }

    func clearUnavailableLiveSubtitleAudioDeviceSelection() {
        settings.selectedLiveSubtitleAudioDeviceID = validatedAudioDeviceID(settings.selectedLiveSubtitleAudioDeviceID)
    }

    func liveSubtitlePostProcessingIndicator() -> (title: String, subtitle: String, tone: StatusBadge.Tone) {
        guard settings.liveSubtitleMode.requiresPostProcessing else {
            return ("Raw", "Prime is not used in Raw mode.", .neutral)
        }

        guard modelStore.selectedLlamaRuntime?.validation.isValid == true else {
            return ("Needs runtime", "Install the llama.cpp runtime before cleaning or translating subtitles.", .warning)
        }

        guard modelStore.selectedPostProcessingModel?.validation.isValid == true else {
            return ("Needs model", "Download or select the Prime text model before cleaning or translating subtitles.", .warning)
        }

        return ("Ready", modelStore.selectedPostProcessingModel?.displayName ?? "Selected Prime model", .success)
    }

    func setTextResponseSessionCreatedHandler(_ handler: @escaping (UUID, String, String) -> Void) {
        textResponseSessionNotifier.onSessionCreated = handler
    }

    func availableSpeechVoices() -> [SpeechVoice] {
        voiceModeController.availableSpeechVoices
    }

    func previewAssistantConfirmationSound() async {
        await assistantConfirmationSounds.play(
            .voiceReady,
            style: settings.assistantConfirmationSoundStyle
        )
    }

    private func playAssistantConfirmationCue(for command: VoiceModeActivationCommand) async {
        guard settings.isAssistantConfirmationSoundEnabled else {
            return
        }

        let cue = AssistantConfirmationCue.cue(
            for: command,
            activeSessionKind: textResponseSessions.activeSession?.kind
        )
        await assistantConfirmationSounds.play(
            cue,
            style: settings.assistantConfirmationSoundStyle
        )
    }

    func captureSelectedText() async -> String? {
        await selectedTextCapture.captureSelectedText()
    }

    func cleanUpSelectedText() async -> Bool {
        guard let selectedText = await captureSelectedText() else {
            appState.lastDetail = "No selected text is available to clean up."
            appState.notifyStatusChanged()
            return false
        }

        let cleanupEngine: (any TextCleanupEngine)?
        let shouldShutdownCleanupEngine: Bool

        if settings.isPostProcessingEnabled {
            cleanupEngine = nil
            shouldShutdownCleanupEngine = false
        } else if settings.voiceModeResponseBackend == .localLlama {
            cleanupEngine = GemmaPrimeTextCleanupEngine(textGenerationEngine: localTextGenerationEngine)
            shouldShutdownCleanupEngine = false
        } else if let oneShotCleanupEngine = makeOneShotPrimeCleanupEngine() {
            cleanupEngine = oneShotCleanupEngine
            shouldShutdownCleanupEngine = true
        } else {
            appState.lastError = .cleanupModelNotConfigured
            appState.lastDetail = AppError.cleanupModelNotConfigured.userMessage
            appState.notifyStatusChanged()
            return false
        }

        defer {
            if shouldShutdownCleanupEngine, let cleanupEngine {
                Task {
                    await cleanupEngine.shutdown()
                }
            }
        }

        return await pipeline.cleanAndInsertSelectedText(selectedText, cleanupEngine: cleanupEngine)
    }

    private func makeOneShotPrimeCleanupEngine() -> (any TextCleanupEngine)? {
        guard
            let runtime = modelStore.selectedLlamaRuntime,
            runtime.validation.isValid,
            let selection = modelStore.selectedPostProcessingModel,
            selection.validation.isValid
        else {
            return nil
        }

        return GemmaPrimeTextCleanupEngine(
            textGenerationEngine: Gemma4LocalTextGenerationEngine(
                modelURL: selection.url,
                runtimeURL: runtime.url,
                modelDefinition: selection.modelDefinition,
                displayName: selection.displayName
            ),
            ownsTextGenerationEngine: true
        )
    }

    func voiceModeBackendIndicator() -> (title: String, subtitle: String, isCloud: Bool) {
        switch settings.voiceModeResponseBackend {
        case .localLlama:
            let model = modelStore.selectedPostProcessingModel?.displayName ?? "Selected local llama model"
            return ("Local", model, false)
        case .openAICompatibleCloud:
            let model = settings.voiceModeCloudModel.trimmingCharacters(in: .whitespacesAndNewlines)
            return ("Cloud", model.isEmpty ? "Not configured" : model, true)
        }
    }

    func voiceModeResponseBackendValidationError() -> AppError? {
        guard settings.voiceModeResponseBackend == .openAICompatibleCloud else {
            return nil
        }

        let baseURL = settings.voiceModeCloudBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = settings.voiceModeCloudModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = settings.voiceModeCloudAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextWindowTokens = settings.voiceModeCloudContextWindowTokens

        guard
            !baseURL.isEmpty,
            let url = URL(string: baseURL),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host != nil
        else {
            return .voiceModeResponseNotConfigured
        }

        guard
            !model.isEmpty,
            !apiKey.isEmpty,
            let contextWindowTokens,
            AppSettings.cloudContextWindowTokenRange.contains(contextWindowTokens)
        else {
            return .voiceModeResponseNotConfigured
        }

        return nil
    }

    func reviewVoiceModePrompt(
        command: VoiceModeActivationCommand,
        promptText: String,
        includesSelectionContext: Bool
    ) async -> String? {
        guard isVoiceModePromptPreviewEnabledForCurrentBackend else {
            return promptText
        }

        promptPreviewContinuation?.resume(returning: nil)
        promptPreviewContinuation = nil

        let backend = voiceModeBackendIndicator()
        let request = VoiceModePromptPreviewRequest(
            commandTitle: command.displayName,
            promptText: promptText,
            backendTitle: backend.title,
            backendSubtitle: backend.subtitle,
            isCloudBackend: backend.isCloud,
            includesSelectionContext: includesSelectionContext
        )

        appState.voiceModePromptPreview = request
        appState.lastDetail = "Review the prompt before sending."
        appState.notifyStatusChanged()

        return await withCheckedContinuation { continuation in
            promptPreviewContinuation = continuation
        }
    }

    private var isVoiceModePromptPreviewEnabledForCurrentBackend: Bool {
        switch settings.voiceModeResponseBackend {
        case .localLlama:
            return settings.isLocalVoiceModePromptPreviewEnabled
        case .openAICompatibleCloud:
            return settings.isCloudVoiceModePromptPreviewEnabled
        }
    }

    func resolveVoiceModePromptPreview(id: UUID, promptText: String?) {
        guard appState.voiceModePromptPreview?.id == id else {
            return
        }

        let trimmedText = promptText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedText = trimmedText?.isEmpty == false ? trimmedText : nil
        let continuation = promptPreviewContinuation
        promptPreviewContinuation = nil
        appState.voiceModePromptPreview = nil
        appState.notifyStatusChanged()
        continuation?.resume(returning: resolvedText)
    }

    func cancelVoiceModePromptPreview() {
        guard let request = appState.voiceModePromptPreview else {
            return
        }

        resolveVoiceModePromptPreview(id: request.id, promptText: nil)
    }

    func performVoiceModeAssistantTurn(
        command: VoiceModeActivationCommand,
        userText: String,
        selectedText: String? = nil
    ) async throws -> VoiceModeAssistantTurnResult {
        let trimmedText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw AppError.voiceModeResponseFailed(details: "Assistant request was empty.")
        }

        switch command {
        case .spoken:
            let sessionID = activeSessionID(kind: .voice)
                ?? textResponseSessions.startSession(kind: .voice, titleSeed: trimmedText)
            let response = try await performAssistantSessionTurn(
                sessionID: sessionID,
                userText: trimmedText,
                policy: .finalAnswerOnly
            )
            return VoiceModeAssistantTurnResult(responseText: response.content, delivery: .spoken)

        case .refreshSession:
            let sessionID = textResponseSessions.startSession(kind: .voice, titleSeed: trimmedText)
            let response = try await performAssistantSessionTurn(
                sessionID: sessionID,
                userText: trimmedText,
                policy: .finalAnswerOnly
            )
            return VoiceModeAssistantTurnResult(responseText: response.content, delivery: .spoken)

        case .textResponse:
            let sessionID = textResponseSessions.startSession(kind: .text, titleSeed: trimmedText)
            let response = try await performAssistantSessionTurn(
                sessionID: sessionID,
                userText: trimmedText,
                policy: .finalAnswerOnly
            )
            notifyTextResponseSessionCreated(sessionID: sessionID, responseText: response.content)
            return VoiceModeAssistantTurnResult(responseText: response.content, delivery: .textResponse)

        case .continueTextResponse:
            let sessionID = textResponseSessions.activeSessionID
                ?? textResponseSessions.startSession(kind: .voice, titleSeed: trimmedText)
            let kind = textResponseSessions.kind(for: sessionID) ?? .voice
            let policy: ChatGenerationPolicy = kind == .text
                ? .chat(stream: settings.textResponseStreamsReplies, showReasoning: settings.textResponseShowsReasoning)
                : .finalAnswerOnly
            let response = try await performAssistantSessionTurn(
                sessionID: sessionID,
                userText: trimmedText,
                policy: policy
            )
            let delivery: VoiceModeResponseDelivery = kind == .voice ? .spoken : .textResponse
            return VoiceModeAssistantTurnResult(responseText: response.content, delivery: delivery)

        case .cleanUpSelection:
            throw AppError.voiceModeResponseFailed(details: "Computer cleanup does not generate an assistant response.")

        case .editSelection:
            guard let selectedText = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !selectedText.isEmpty
            else {
                throw AppError.voiceModeResponseFailed(details: "No selected text is available to edit.")
            }

            let editedText = try await editSelectedText(
                selectedText: selectedText,
                instruction: trimmedText
            )
            return VoiceModeAssistantTurnResult(responseText: editedText, delivery: .textResponse)
        }
    }

    private func editSelectedText(selectedText: String, instruction: String) async throws -> String {
        if let validationError = voiceModeResponseBackendValidationError() {
            throw validationError
        }

        let request = VoiceModeEditPrompt(
            selectedText: selectedText,
            instruction: instruction
        ).chatGenerationRequest()
        let budgetedRequest = AssistantContextWindow.reduce(
            request,
            configuration: AssistantContextWindowConfiguration(
                contextWindowTokens: assistantContextWindowTokens(),
                responseReserveTokens: request.maxTokens
            )
        )
        let response = try await currentVoiceModeTextGenerationEngine().generate(request: budgetedRequest)
        let editedText = response.content
        guard !editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.voiceModeResponseFailed(details: "The response provider returned an empty edit.")
        }

        try await pipeline.insertReplacementText(editedText)
        return editedText
    }

    @discardableResult
    func continueTextResponseSession(sessionID: UUID, userText: String) async -> String? {
        let trimmedText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        guard !textResponseSessions.isGenerating(sessionID: sessionID) else {
            return nil
        }

        if let validationError = voiceModeResponseBackendValidationError() {
            appState.lastError = validationError
            appState.lastDetail = validationError.userMessage
            appState.notifyStatusChanged()
            return nil
        }

        textResponseSessions.select(sessionID)

        let task = Task<String?, Never> { @MainActor [weak self] in
            guard let self else {
                return nil
            }

            return await self.performContinueTextResponseSession(sessionID: sessionID, trimmedText: trimmedText)
        }
        textResponseGenerationTasks[sessionID] = task
        let response = await task.value
        textResponseGenerationTasks[sessionID] = nil
        return response
    }

    private func activeSessionID(kind: TextResponseSessionKind) -> UUID? {
        guard let session = textResponseSessions.activeSession, session.kind == kind else {
            return nil
        }

        return session.id
    }

    private func performContinueTextResponseSession(sessionID: UUID, trimmedText: String) async -> String? {
        let policy = ChatGenerationPolicy.chat(
            stream: settings.textResponseStreamsReplies,
            showReasoning: settings.textResponseShowsReasoning
        )

        do {
            let response = try await performAssistantSessionTurn(
                sessionID: sessionID,
                userText: trimmedText,
                policy: policy
            )
            return response.content
        } catch let error as AppError {
            textResponseSessions.setError(error.userMessage, sessionID: sessionID)
            appState.lastError = error
            appState.lastDetail = error.userMessage
            appState.notifyStatusChanged()
        } catch is CancellationError {
            textResponseSessions.setError("Generation stopped.", sessionID: sessionID)
            appState.lastDetail = "Text response stopped."
            appState.notifyStatusChanged()
        } catch {
            textResponseSessions.setError(error.localizedDescription, sessionID: sessionID)
            appState.lastError = .voiceModeResponseFailed(details: error.localizedDescription)
            appState.lastDetail = "Text response failed."
            appState.notifyStatusChanged()
        }

        return nil
    }

    private func performAssistantSessionTurn(
        sessionID: UUID,
        userText: String,
        policy: ChatGenerationPolicy
    ) async throws -> ChatGenerationResult {
        guard !textResponseSessions.isGenerating(sessionID: sessionID) else {
            throw AppError.voiceModeResponseFailed(details: "The active assistant session is still generating.")
        }

        if let validationError = voiceModeResponseBackendValidationError() {
            throw validationError
        }

        textResponseSessions.appendUserMessage(sessionID: sessionID, text: userText)
        let messages = textResponseSessions.messages(for: sessionID)
        let kind = textResponseSessions.kind(for: sessionID) ?? .text
        let request = TextResponseSessionPrompt(
            messages: messages,
            sessionKind: kind
        ).chatGenerationRequest(policy: policy)
        let budgetedRequest = AssistantContextWindow.reduce(
            request,
            configuration: assistantContextWindowConfiguration(for: kind, request: request)
        )

        do {
            if budgetedRequest.prefersStreaming {
                return try await continueTextResponseSessionStreaming(
                    sessionID: sessionID,
                    request: budgetedRequest
                )
            }

            let response = try await currentVoiceModeTextGenerationEngine().generate(request: budgetedRequest)
            let trimmedResponse = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedResponse.isEmpty else {
                throw AppError.voiceModeResponseFailed(details: "The response provider returned an empty assistant response.")
            }

            let finalResponse = ChatGenerationResult(
                content: trimmedResponse,
                reasoning: settings.textResponseShowsReasoning ? response.reasoning : ""
            )
            textResponseSessions.appendAssistantMessage(
                sessionID: sessionID,
                text: finalResponse.content,
                reasoning: kind == .text ? finalResponse.reasoning : ""
            )
            return finalResponse
        } catch let error as AppError {
            textResponseSessions.setError(error.userMessage, sessionID: sessionID)
            throw error
        } catch is CancellationError {
            textResponseSessions.setError("Generation stopped.", sessionID: sessionID)
            throw CancellationError()
        } catch {
            textResponseSessions.setError(error.localizedDescription, sessionID: sessionID)
            throw error
        }
    }

    private func notifyTextResponseSessionCreated(sessionID: UUID, responseText: String) {
        let title = textResponseSessions.sessions.first { $0.id == sessionID }?.title ?? "Text response"
        textResponseSessionNotifier.sessionCreated(
            id: sessionID,
            title: title,
            responseText: responseText
        )
    }

    private func assistantContextWindowConfiguration(
        for kind: TextResponseSessionKind,
        request: ChatGenerationRequest
    ) -> AssistantContextWindowConfiguration {
        AssistantContextWindowConfiguration(
            contextWindowTokens: assistantContextWindowTokens(),
            responseReserveTokens: request.maxTokens,
            maximumRecentMessages: kind == .voice ? Self.voiceAssistantMaximumRecentMessages : nil
        )
    }

    private func assistantContextWindowTokens() -> Int {
        switch settings.voiceModeResponseBackend {
        case .localLlama:
            return Self.localAssistantContextWindowTokens
        case .openAICompatibleCloud:
            return settings.voiceModeCloudContextWindowTokens ?? AppSettings.cloudContextWindowTokenRange.lowerBound
        }
    }

    private func continueTextResponseSessionStreaming(
        sessionID: UUID,
        request: ChatGenerationRequest
    ) async throws -> ChatGenerationResult {
        guard let messageID = textResponseSessions.startAssistantStreamingMessage(sessionID: sessionID) else {
            throw AppError.voiceModeResponseFailed(details: "Could not start a streaming chat response.")
        }

        do {
            let response = try await currentVoiceModeTextGenerationEngine().stream(request: request) { [weak self] event in
                switch event {
                case .contentDelta(let delta):
                    self?.textResponseSessions.appendAssistantContentDelta(
                        sessionID: sessionID,
                        messageID: messageID,
                        delta: delta
                    )
                case .reasoningDelta(let delta):
                    self?.textResponseSessions.appendAssistantReasoningDelta(
                        sessionID: sessionID,
                        messageID: messageID,
                        delta: delta
                    )
                }
            }
            let trimmedResponse = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedResponse.isEmpty else {
                throw AppError.voiceModeResponseFailed(details: "The response provider returned an empty chat response.")
            }

            textResponseSessions.finishAssistantStreamingMessage(
                sessionID: sessionID,
                messageID: messageID,
                finalContent: trimmedResponse,
                finalReasoning: settings.textResponseShowsReasoning ? response.reasoning : ""
            )
            return ChatGenerationResult(
                content: trimmedResponse,
                reasoning: settings.textResponseShowsReasoning ? response.reasoning : ""
            )
        } catch let error as AppError {
            textResponseSessions.failAssistantStreamingMessage(
                sessionID: sessionID,
                messageID: messageID,
                error: error.userMessage
            )
            throw error
        } catch {
            textResponseSessions.failAssistantStreamingMessage(
                sessionID: sessionID,
                messageID: messageID,
                error: error.localizedDescription
            )
            throw error
        }
    }

    func togglePostProcessingEnabledFromHotkey() {
        let requestedState = !settings.isPostProcessingEnabled
        setPostProcessingEnabled(requestedState)
        guard settings.isPostProcessingEnabled == requestedState else {
            return
        }

        appState.lastDetail = settings.isPostProcessingEnabled ? "Prime enabled." : "Prime disabled."
        appState.notifyStatusChanged()
    }

    func setVoiceGuardEnabled(_ isEnabled: Bool) {
        guard isEnabled else {
            settings.isVoiceGuardEnabled = false
            appState.lastDetail = "Trusted Voice disabled."
            appState.notifyStatusChanged()
            return
        }

        guard validateVoiceGuardCanEnable() else {
            return
        }

        settings.isVoiceGuardEnabled = true
        appState.lastError = nil
        appState.lastDetail = "Trusted Voice enabled."
        appState.notifyStatusChanged()
    }

    func toggleVoiceGuardFromHotkey() {
        setVoiceGuardEnabled(!settings.isVoiceGuardEnabled)
    }

    @discardableResult
    private func validateVoiceGuardCanEnable() -> Bool {
        guard speakerProfileStore.profile != nil else {
            appState.lastError = .speakerVerificationFailed(details: "Record a voice profile before enabling Trusted Voice.")
            appState.lastDetail = "Voice profile is missing."
            appState.notifyStatusChanged()
            return false
        }

        guard speakerProfileStore.profile?.modelID == SpeakerVerifierRuntimeLayout.modelID else {
            appState.lastError = .speakerVerificationFailed(details: "Re-enroll your voice profile before enabling Trusted Voice.")
            appState.lastDetail = "Voice profile needs to be re-enrolled."
            appState.notifyStatusChanged()
            return false
        }

        guard SpeakerVerifierRuntimeLayout.isInstalled() else {
            appState.lastError = .speakerVerificationFailed(details: "Install the speaker verifier before enabling Trusted Voice.")
            appState.lastDetail = "Speaker verifier is not installed."
            appState.notifyStatusChanged()
            return false
        }

        return true
    }

    func selectPostProcessingModel(at url: URL) async {
        await modelStore.selectPostProcessingModel(at: url)
        disablePostProcessingIfUnavailable()
        configurePostProcessingEngineFromSelectedModel()
    }

    func selectPostProcessingModelDefinition(_ definition: PostProcessingModelDefinition) async {
        await modelStore.selectPostProcessingModelDefinition(definition)
        disablePostProcessingIfUnavailable()
        configurePostProcessingEngineFromSelectedModel()
    }

    func clearPostProcessingModelSelection() {
        modelStore.clearPostProcessingSelection()
        disablePostProcessingIfUnavailable()
        configurePostProcessingEngineFromSelectedModel()
    }

    func installManagedLlamaRuntime() async {
        await modelStore.installManagedLlamaRuntime()
        configurePostProcessingEngineFromSelectedModel()
    }

    func selectLlamaRuntime(at url: URL) async {
        await modelStore.selectLlamaRuntime(at: url)
        disablePostProcessingIfUnavailable()
        configurePostProcessingEngineFromSelectedModel()
    }

    func clearLlamaRuntimeSelection() {
        modelStore.clearLlamaRuntimeSelection()
        disablePostProcessingIfUnavailable()
        configurePostProcessingEngineFromSelectedModel()
    }

    func installManagedPostProcessingModel() async {
        await modelStore.installManagedPostProcessingModel()
        configurePostProcessingEngineFromSelectedModel()
    }

    func deleteManagedPostProcessingModel() async {
        await modelStore.deleteManagedPostProcessingModel()
        disablePostProcessingIfUnavailable()
        configurePostProcessingEngineFromSelectedModel()
    }

    private func disablePostProcessingIfUnavailable() {
        guard settings.isPostProcessingEnabled, !canEnablePostProcessing else {
            return
        }

        settings.isPostProcessingEnabled = false
        appState.lastDetail = "Prime disabled. \(postProcessingUnavailableDetail)"
        appState.notifyStatusChanged()
    }

    private func configureASREngineFromSelectedModel() {
        guard
            let selection = modelStore.selectedASRModel,
            selection.validation.isValid
        else {
            pipeline.setASREngine(UnconfiguredASREngine())
            liveSubtitleController.setASREngine(UnconfiguredASREngine())
            return
        }

        let engine = FluidAudioParakeetEngine(
            modelURL: selection.url,
            computeMode: .all
        )
        pipeline.setASREngine(engine)
        liveSubtitleController.setASREngine(engine)
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

    private static func makeCleanupContext(settings: AppSettings) -> CleanupContext {
        let targetApplication: TargetAppContext?
        let appFormattingProfile: AppFormattingProfile?

        if settings.isPrimeAppAwareFormattingEnabled {
            let appContext = ActiveApplicationService().frontmostApplication()
            targetApplication = appContext
            appFormattingProfile = AppFormattingProfile.profile(for: appContext)
        } else {
            targetApplication = nil
            appFormattingProfile = nil
        }

        let vocabularyEntries = settings.isPrimeCustomVocabularyEnabled
            ? settings.primeVocabularyEntries
            : []

        return CleanupContext(
            targetApplication: targetApplication,
            appFormattingProfile: appFormattingProfile,
            vocabularyEntries: vocabularyEntries
        )
    }

    private func configurePostProcessingEngineFromSelectedModel() {
        if settings.isPostProcessingEnabled, !canEnablePostProcessing {
            settings.isPostProcessingEnabled = false
        }

        let shouldKeepLocalTextModelReady = self.shouldKeepLocalTextModelReady
        let hasValidLocalTextModel =
            modelStore.selectedLlamaRuntime?.validation.isValid == true
            && modelStore.selectedPostProcessingModel?.validation.isValid == true
        let selectedEngineKey: LocalTextGenerationEngineKey?
        if
            hasValidLocalTextModel,
            let runtime = modelStore.selectedLlamaRuntime,
            let selection = modelStore.selectedPostProcessingModel
        {
            selectedEngineKey = LocalTextGenerationEngineKey(runtime: runtime, model: selection)
        } else {
            selectedEngineKey = nil
        }
        let desiredEngineKey = shouldKeepLocalTextModelReady ? selectedEngineKey : nil
        let wasUsingLiveSubtitlePrime = liveSubtitleTextGenerationEngineKey != nil
        var didChangeEngine = false

        if let desiredEngineKey {
            cancelLocalTextGenerationIdleShutdown()
            didChangeEngine = desiredEngineKey != localTextGenerationEngineKey
            if didChangeEngine {
                configureLocalTextGenerationEngine(key: desiredEngineKey)
            }
        } else if localTextGenerationEngineKey != nil {
            if wasUsingLiveSubtitlePrime {
                scheduleLocalTextGenerationIdleShutdown()
            } else {
                didChangeEngine = true
                unconfigureLocalTextGenerationEngine()
            }
        }

        if didChangeEngine || desiredEngineKey != nil || wasUsingLiveSubtitlePrime {
            localTextGenerationConfigurationGeneration += 1
        }

        let configuredEngine: any LocalTextGenerationEngine = desiredEngineKey == nil
            ? UnconfiguredLocalTextGenerationEngine()
            : localTextGenerationEngine
        voiceModeController.setTextGenerationEngine(
            voiceModeTextGenerationEngine(localTextGenerationEngine: configuredEngine)
        )
        let cleanupTextGenerationEngine: any LocalTextGenerationEngine
        if settings.isPostProcessingEnabled {
            cleanupTextGenerationEngine = configuredEngine
        } else {
            cleanupTextGenerationEngine = UnconfiguredLocalTextGenerationEngine()
        }
        pipeline.setCleanupEngine(
            GemmaPrimeTextCleanupEngine(
                textGenerationEngine: cleanupTextGenerationEngine
            )
        )
        let subtitleShouldUseLocalTextEngine =
            settings.isLiveSubtitlesEnabled
            && settings.liveSubtitleMode.requiresPostProcessing
            && desiredEngineKey != nil
        let subtitleTextGenerationEngine: any LocalTextGenerationEngine = subtitleShouldUseLocalTextEngine
            ? configuredEngine
            : UnconfiguredLocalTextGenerationEngine()
        let subtitleEngineKey = subtitleShouldUseLocalTextEngine ? desiredEngineKey : nil
        if didChangeEngine || subtitleEngineKey != liveSubtitleTextGenerationEngineKey {
            liveSubtitleController.setTextGenerationEngine(subtitleTextGenerationEngine)
            liveSubtitleTextGenerationEngineKey = subtitleEngineKey
        }

        if shouldKeepLocalTextModelReady, hasValidLocalTextModel {
            let configurationGeneration = localTextGenerationConfigurationGeneration
            preloadLocalTextGenerationModel(configuredEngine, generation: configurationGeneration)
        }
    }

    private func configureLocalTextGenerationEngine(key: LocalTextGenerationEngineKey) {
        guard
            let runtime = modelStore.selectedLlamaRuntime,
            let selection = modelStore.selectedPostProcessingModel
        else {
            return
        }

        let previousTextGenerationEngine = localTextGenerationEngine
        localTextGenerationEngine = Gemma4LocalTextGenerationEngine(
            modelURL: selection.url,
            runtimeURL: runtime.url,
            modelDefinition: selection.modelDefinition,
            displayName: selection.displayName
        )
        localTextGenerationEngineKey = key
        DiagnosticLog.write(
            "local text engine configured runtime=\(key.runtimePath) model=\(key.modelPath) definition=\(key.modelDefinitionID)"
        )

        Task {
            await previousTextGenerationEngine.shutdown()
        }
    }

    private func unconfigureLocalTextGenerationEngine() {
        cancelLocalTextGenerationIdleShutdown()

        let previousTextGenerationEngine = localTextGenerationEngine
        localTextGenerationEngine = UnconfiguredLocalTextGenerationEngine()
        localTextGenerationEngineKey = nil
        DiagnosticLog.write("local text engine unconfigured")

        Task {
            await previousTextGenerationEngine.shutdown()
        }
    }

    private func scheduleLocalTextGenerationIdleShutdown() {
        guard localTextGenerationIdleShutdownTask == nil,
              let scheduledKey = localTextGenerationEngineKey
        else {
            return
        }

        DiagnosticLog.write(
            "local text engine idle shutdown scheduled delay=\(Self.liveSubtitlePrimeIdleShutdownDelaySeconds)s"
        )
        localTextGenerationIdleShutdownTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(Int(Self.liveSubtitlePrimeIdleShutdownDelaySeconds * 1000)))
            } catch {
                return
            }

            guard let self else {
                return
            }

            self.localTextGenerationIdleShutdownTask = nil
            guard self.localTextGenerationEngineKey == scheduledKey,
                  !self.shouldKeepLocalTextModelReady
            else {
                return
            }

            let idleTextGenerationEngine = self.localTextGenerationEngine
            self.localTextGenerationEngine = UnconfiguredLocalTextGenerationEngine()
            self.localTextGenerationEngineKey = nil
            self.localTextGenerationConfigurationGeneration += 1
            DiagnosticLog.write("local text engine idle shutdown firing")

            Task {
                await idleTextGenerationEngine.shutdown()
            }
        }
    }

    private func cancelLocalTextGenerationIdleShutdown() {
        guard let localTextGenerationIdleShutdownTask else {
            return
        }

        localTextGenerationIdleShutdownTask.cancel()
        self.localTextGenerationIdleShutdownTask = nil
        DiagnosticLog.write("local text engine idle shutdown canceled")
    }

    private var shouldKeepLocalTextModelReady: Bool {
        settings.isPostProcessingEnabled
            || (settings.isVoiceModeEnabled && settings.voiceModeResponseBackend == .localLlama)
            || (settings.isLiveSubtitlesEnabled && settings.liveSubtitleMode.requiresPostProcessing)
    }

    private func voiceModeTextGenerationEngine(
        localTextGenerationEngine: any LocalTextGenerationEngine
    ) -> any LocalTextGenerationEngine {
        guard settings.isVoiceModeEnabled else {
            return UnconfiguredLocalTextGenerationEngine()
        }

        switch settings.voiceModeResponseBackend {
        case .localLlama:
            return localTextGenerationEngine
        case .openAICompatibleCloud:
            let settings = settings
            return OpenAICompatibleVoiceModeTextGenerationEngine(
                baseURL: { settings.voiceModeCloudBaseURL },
                model: { settings.voiceModeCloudModel },
                apiKey: { settings.voiceModeCloudAPIKey },
                proxySettings: { settings.proxySettings }
            )
        }
    }

    private func currentVoiceModeTextGenerationEngine() -> any LocalTextGenerationEngine {
        switch settings.voiceModeResponseBackend {
        case .localLlama:
            return localTextGenerationEngine
        case .openAICompatibleCloud:
            let settings = settings
            return OpenAICompatibleVoiceModeTextGenerationEngine(
                baseURL: { settings.voiceModeCloudBaseURL },
                model: { settings.voiceModeCloudModel },
                apiKey: { settings.voiceModeCloudAPIKey },
                proxySettings: { settings.proxySettings }
            )
        }
    }

    private func preloadLocalTextGenerationModel(_ engine: any LocalTextGenerationEngine, generation: Int) {
        appState.lastDetail = "Loading local text model..."
        DiagnosticLog.write("preloadLocalTextGenerationModel started generation=\(generation) engine=\(engine.displayName)")
        appState.notifyStatusChanged()

        Task { @MainActor in
            do {
                try await engine.prepare()
                guard generation == localTextGenerationConfigurationGeneration else {
                    DiagnosticLog.write(
                        "preloadLocalTextGenerationModel ignored stale completion generation=\(generation) active=\(localTextGenerationConfigurationGeneration)"
                    )
                    return
                }

                DiagnosticLog.write("preloadLocalTextGenerationModel completed generation=\(generation)")
                appState.lastDetail = "Local text model ready."
                appState.notifyStatusChanged()
            } catch let error as AppError {
                guard generation == localTextGenerationConfigurationGeneration else {
                    DiagnosticLog.write(
                        "preloadLocalTextGenerationModel ignored stale AppError generation=\(generation) active=\(localTextGenerationConfigurationGeneration) details=\(error.technicalDetails ?? "none")"
                    )
                    return
                }

                DiagnosticLog.write("preloadLocalTextGenerationModel AppError: \(error.userMessage) details=\(error.technicalDetails ?? "none")")
                appState.lastError = error
                appState.lastDetail = error.userMessage
                appState.notifyStatusChanged()
            } catch {
                guard generation == localTextGenerationConfigurationGeneration else {
                    DiagnosticLog.write(
                        "preloadLocalTextGenerationModel ignored stale Error generation=\(generation) active=\(localTextGenerationConfigurationGeneration) error=\(error.localizedDescription)"
                    )
                    return
                }

                DiagnosticLog.write("preloadLocalTextGenerationModel Error: \(error.localizedDescription)")
                appState.lastError = .cleanupFailed(details: error.localizedDescription)
                appState.lastDetail = "Local text model failed to load."
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
                    details: "Prime or Trusted Voice hotkeys could not be registered, so EchoV kept the core dictation hotkeys active."
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
            ("Hands-free", settings.voiceGateHotkey),
            ("Assistant", settings.voiceModeActivationHotkey),
            ("Assistant text", settings.voiceModeTextActivationHotkey),
            ("Live Subtitles", settings.liveSubtitleHotkey),
            ("Stop EchoV", settings.stopHotkey)
        ]

        if includeUtilityHotkeys {
            configuredHotkeys.append(contentsOf: [
                ("Prime", settings.primeToggleHotkey),
                ("Trusted Voice", settings.voiceGateVerifierToggleHotkey)
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
            throw AppError.hotkeyUnavailable(details: "Toggle and Hands-free cannot use the same hotkey.")
        }

        if
            let pushToTalkHotkey = settings.pushToTalkHotkey,
            let voiceGateHotkey = settings.voiceGateHotkey,
            pushToTalkHotkey == voiceGateHotkey
        {
            throw AppError.hotkeyUnavailable(details: "Push-to-talk and Hands-free cannot use the same hotkey.")
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
                            self?.toggleVoiceGuardFromHotkey()
                        }
                    },
                    onReleased: nil
                )
            )
        }

        if let voiceModeActivationHotkey = settings.voiceModeActivationHotkey {
            registrations.append(
                HotkeyRegistration(
                    id: HotkeyID.voiceModeActivation,
                    binding: voiceModeActivationHotkey,
                    onPressed: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.handleVoiceModeHotkey(command: .spoken)
                        }
                    },
                    onReleased: nil
                )
            )
        }

        if let voiceModeTextActivationHotkey = settings.voiceModeTextActivationHotkey {
            registrations.append(
                HotkeyRegistration(
                    id: HotkeyID.voiceModeTextActivation,
                    binding: voiceModeTextActivationHotkey,
                    onPressed: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.handleVoiceModeHotkey(command: .textResponse)
                        }
                    },
                    onReleased: nil
                )
            )
        }

        if let liveSubtitleHotkey = settings.liveSubtitleHotkey {
            registrations.append(
                HotkeyRegistration(
                    id: HotkeyID.liveSubtitles,
                    binding: liveSubtitleHotkey,
                    onPressed: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.handleLiveSubtitleHotkey()
                        }
                    },
                    onReleased: nil
                )
            )
        }

        if let stopHotkey = settings.stopHotkey {
            registrations.append(
                HotkeyRegistration(
                    id: HotkeyID.stop,
                    binding: stopHotkey,
                    onPressed: { [weak self] in
                        Task { @MainActor [weak self] in
                            await self?.stopActiveWork()
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
            \.voiceGateVerifierToggleHotkey,
            \.voiceModeActivationHotkey,
            \.voiceModeTextActivationHotkey,
            \.liveSubtitleHotkey,
            \.stopHotkey
        ]

        return bindings.allSatisfy { keyPath in
            keyPath == excludedKeyPath || settings[keyPath: keyPath] != binding
        }
    }

    private func handleToggleHotkey() async {
        switch recordingTrigger {
        case nil, .voiceMode:
            guard makeVoiceModeYieldToManualRecordingIfNeeded(),
                  appState.state.canStartRecording
            else {
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
            await startVoiceModeAfterCurrentTaskIfNeeded()
        case .pushToTalk:
            return
        case .voiceGate:
            return
        case .liveSubtitles:
            return
        case .voiceProfileEnrollment:
            return
        }
    }

    private func handlePushToTalkPressed() async {
        guard makeVoiceModeYieldToManualRecordingIfNeeded(),
              recordingTrigger == nil,
              appState.state.canStartRecording
        else {
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
        await startVoiceModeAfterCurrentTaskIfNeeded()
    }

    private func handleVoiceGateHotkey() async {
        if isVoiceGateArmed {
            disarmVoiceGate()
            return
        }

        guard makeVoiceModeYieldToManualRecordingIfNeeded(),
              recordingTrigger == nil,
              appState.state.canStartRecording
        else {
            return
        }

        isVoiceGateArmed = true
        recordingTrigger = .voiceGate
        await startVoiceGateListening()
    }

    private func makeVoiceModeYieldToManualRecordingIfNeeded() -> Bool {
        guard recordingTrigger == .voiceMode else {
            return recordingTrigger == nil
        }

        guard appState.state.canYieldVoiceModeToManualRecording else {
            return false
        }

        cancelVoiceModePromptPreview()
        voiceModeController.stop()
        recordingTrigger = nil
        appState.lastError = nil
        return true
    }

    private func handleVoiceModeHotkey(command: VoiceModeActivationCommand) async {
        guard settings.isVoiceModeEnabled else {
            appState.lastError = .recordingFailed(details: "Enable Assistant before using its activation hotkey.")
            appState.lastDetail = "Assistant is off."
            appState.notifyStatusChanged()
            return
        }

        guard recordingTrigger == nil || recordingTrigger == .voiceMode else {
            return
        }

        cancelVoiceModePromptPreview()
        recordingTrigger = .voiceMode
        await voiceModeController.activateManually(command: command)
    }

    private func handleLiveSubtitleHotkey() async {
        if liveSubtitles.isRunning {
            settings.isLiveSubtitlesEnabled = false
            liveSubtitleController.stop()
            if recordingTrigger == .liveSubtitles {
                recordingTrigger = nil
            }
            if settings.isVoiceModeEnabled {
                await startVoiceModeIfPossible()
            }
            return
        }

        settings.isLiveSubtitlesEnabled = true
        configurePostProcessingEngineFromSelectedModel()
        await startLiveSubtitlesIfPossible()
    }

    func stopActiveWork() async {
        for task in textResponseGenerationTasks.values {
            task.cancel()
        }
        textResponseGenerationTasks.removeAll()

        voiceGateCapture.stop()
        cancelVoiceModePromptPreview()
        voiceModeController.stop()
        liveSubtitleController.stop()
        settings.isLiveSubtitlesEnabled = false
        isVoiceGateArmed = false

        if isVoiceProfileEnrollmentRecording {
            _ = try? await voiceProfileEnrollmentRecorder.stop()
            isVoiceProfileEnrollmentRecording = false
            voiceProfileEnrollmentRecording = nil
        }

        await pipeline.cancelRecording()
        recordingTrigger = nil
        appState.lastError = nil
        appState.lastDetail = "EchoV stopped."
        appState.state = .cancelled
        appState.notifyStatusChanged()

        if settings.isVoiceModeEnabled {
            await startVoiceModeIfPossible()
        }
    }

    private func startLiveSubtitlesIfPossible() async {
        guard settings.isLiveSubtitlesEnabled else {
            return
        }

        clearUnavailableLiveSubtitleAudioDeviceSelection()

        guard makeVoiceModeYieldToManualRecordingIfNeeded(),
              recordingTrigger == nil,
              appState.state.canStartRecording
        else {
            liveSubtitles.updateStatus("Stop the current EchoV task before starting subtitles.")
            settings.isLiveSubtitlesEnabled = false
            return
        }

        recordingTrigger = .liveSubtitles
        await liveSubtitleController.start()

        if !liveSubtitles.isRunning {
            recordingTrigger = nil
            settings.isLiveSubtitlesEnabled = false
        }
    }

    private func validatedAudioDeviceID(_ deviceID: String?) -> String? {
        guard let deviceID, !deviceID.isEmpty else {
            return nil
        }

        guard MicrophoneDeviceCatalog.inputDevices().contains(where: { $0.id == deviceID }) else {
            return nil
        }

        return deviceID
    }

    private func startVoiceModeIfPossible() async {
        guard settings.isVoiceModeEnabled else {
            return
        }

        guard recordingTrigger == nil, appState.state.canStartRecording else {
            appState.lastDetail = "Assistant will start after the current task finishes."
            appState.notifyStatusChanged()
            return
        }

        recordingTrigger = .voiceMode
        await voiceModeController.start()
    }

    private func startVoiceModeAfterCurrentTaskIfNeeded() async {
        guard settings.isVoiceModeEnabled else {
            return
        }

        await startVoiceModeIfPossible()
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
        appState.lastDetail = "Hands-free is armed. Speak when ready."
        setState(.listening)

        do {
            try await voiceGateCapture.start(
                configuration: VoiceGateCaptureConfiguration(
                    silenceTimeoutSeconds: settings.voiceGateSilenceTimeout.seconds,
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

        if shouldUseVoiceGuard(for: .voiceGate) {
            do {
                let isAccepted = try await verifyVoiceGuardSpeaker(recordedAudio, workflow: .voiceGate)
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

    private func shouldUseVoiceGuard(for workflow: VoiceGuardWorkflow) -> Bool {
        guard settings.isVoiceGuardEnabled else {
            return false
        }

        switch workflow {
        case .voiceGate:
            return settings.isVoiceGuardEnabledForVoiceGate
        case .voiceModeCommand:
            return settings.isVoiceGuardEnabledForVoiceModeCommands
        case .voiceModeRequest:
            return settings.isVoiceGuardEnabledForVoiceModeRequests
        }
    }

    private func verifyVoiceModeCommandSpeaker(_ recordedAudio: RecordedAudio) async throws -> Bool {
        guard shouldUseVoiceGuard(for: .voiceModeCommand) else {
            return true
        }

        return try await verifyVoiceGuardSpeaker(recordedAudio, workflow: .voiceModeCommand)
    }

    private func verifyVoiceModeRequestSpeaker(_ recordedAudio: RecordedAudio) async throws -> Bool {
        guard shouldUseVoiceGuard(for: .voiceModeRequest) else {
            return true
        }

        return try await verifyVoiceGuardSpeaker(recordedAudio, workflow: .voiceModeRequest)
    }

    private func verifyVoiceGuardSpeaker(
        _ recordedAudio: RecordedAudio,
        workflow: VoiceGuardWorkflow
    ) async throws -> Bool {
        guard let profile = speakerProfileStore.profile else {
            throw AppError.speakerVerificationFailed(details: "Turn off Trusted Voice or record a voice profile first.")
        }

        let threshold = settings.voiceGateSpeakerMatchStrictness.minimumSimilarity
        let mode = settings.voiceGateSpeakerVerificationMode
        appState.lastDetail = mode == .continuous ? workflow.checkingContinuousDetail : workflow.checkingStartDetail
        setState(.transcribing(status: "Checking voice..."))

        let windows = try verificationWindows(for: recordedAudio, mode: mode)
        defer {
            temporaryAudioStore.delete(windows.map(\.fileURL))
        }

        guard !windows.isEmpty else {
            throw AppError.speakerVerificationFailed(details: workflow.emptyWindowsError)
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
                    ? workflow.continuousMismatchDetail
                    : "Different voice ignored."
                setState(.cancelled)
                return false
            }

            acceptedSimilarities.append(result.similarity)
        }

        let minimumSimilarity = acceptedSimilarities.min() ?? 0
        appState.lastDetail = mode == .continuous
            ? String(format: workflow.matchedContinuousDetail, minimumSimilarity * 100)
            : String(format: workflow.matchedStartDetail, minimumSimilarity * 100)
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
        case .idle,
             .recording,
             .voiceModeWakeListening,
             .voiceModeCheckingWakePhrase,
             .voiceModePromptListening,
             .voiceModePromptRecording,
             .voiceModeThinking,
             .voiceModeSpeaking,
             .transcribing,
             .cleaning,
             .inserting,
             .completed,
             .failed,
             .cancelled:
            break
        }

        recordingTrigger = nil
        appState.lastDetail = "Hands-free is muted."
        appState.notifyStatusChanged()

        if settings.isVoiceModeEnabled {
            Task {
                await startVoiceModeIfPossible()
            }
        }
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
        case .listening,
             .recording,
             .voiceGateRecording,
             .voiceModeWakeListening,
             .voiceModeCheckingWakePhrase,
             .voiceModePromptListening,
             .voiceModePromptRecording,
             .voiceModeThinking,
             .voiceModeSpeaking,
             .transcribing,
             .cleaning,
             .inserting:
            false
        }
    }

    var canYieldVoiceModeToManualRecording: Bool {
        switch self {
        case .voiceModeWakeListening,
             .voiceModeCheckingWakePhrase,
             .voiceModePromptListening,
             .completed,
             .failed,
             .cancelled:
            return true
        case .idle,
             .listening,
             .recording,
             .voiceGateRecording,
             .voiceModePromptRecording,
             .voiceModeThinking,
             .voiceModeSpeaking,
             .transcribing,
             .cleaning,
             .inserting:
            return false
        }
    }

    var isRecording: Bool {
        switch self {
        case .recording, .voiceGateRecording, .voiceModePromptRecording:
            return true
        case .idle,
             .listening,
             .voiceModeWakeListening,
             .voiceModeCheckingWakePhrase,
             .voiceModePromptListening,
             .voiceModeThinking,
             .voiceModeSpeaking,
             .transcribing,
             .cleaning,
             .inserting,
             .completed,
             .failed,
             .cancelled:
            return false
        }
    }
}
