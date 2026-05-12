import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {
    private enum HotkeyID {
        static let toggle = UInt32(1)
        static let pushToTalk = UInt32(2)
    }

    private enum RecordingTrigger {
        case toggle
        case pushToTalk
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

    private let hotkeyService: any HotkeyService
    private var hasStarted = false
    private var recordingTrigger: RecordingTrigger?

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
        hotkeyService: any HotkeyService
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
        self.hotkeyService = hotkeyService
    }

    static func bootstrap() -> AppContainer {
        let settings = AppSettings()
        let appState = AppState()
        let permissionState = PermissionState()
        let microphonePermission = MicrophonePermissionService()
        let accessibilityPermission = AccessibilityPermissionService()
        let startupPermission = StartupPermissionService()
        let modelStore = ModelStore()
        let historyStore = TranscriptHistoryStore()
        let temporaryAudioStore = TemporaryAudioStore()
        let licensesStore = LicensesStore()

        let pipeline = DictationPipeline(
            appState: appState,
            recorder: AVFoundationAudioRecorder(microphonePermission: microphonePermission),
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
            hotkeyService: CarbonHotkeyService()
        )
    }

    func start() {
        hasStarted = true
        refreshPermissions()

        Task {
            await historyStore.load()
            await modelStore.restoreSelection()
            configureASREngineFromSelectedModel()
            configurePostProcessingEngineFromSelectedModel()
        }

        registerHotkeys()
    }

    func stop() {
        hasStarted = false
        hotkeyService.unregister()
        pipeline.setCleanupEngine(
            GemmaPrimeTextCleanupEngine(
                textGenerationEngine: UnconfiguredLocalTextGenerationEngine()
            )
        )
    }

    func setToggleHotkey(_ binding: HotkeyBinding?) {
        guard binding == nil || binding != settings.pushToTalkHotkey else {
            appState.lastError = .hotkeyUnavailable(details: "Toggle and push-to-talk cannot use the same hotkey.")
            return
        }

        settings.toggleHotkey = binding
        registerHotkeys()
    }

    func setPushToTalkHotkey(_ binding: HotkeyBinding?) {
        guard binding == nil || binding != settings.toggleHotkey else {
            appState.lastError = .hotkeyUnavailable(details: "Toggle and push-to-talk cannot use the same hotkey.")
            return
        }

        settings.pushToTalkHotkey = binding
        registerHotkeys()
    }

    func resetHotkeysToDefaults() {
        settings.resetHotkeysToDefaults()
        registerHotkeys()
    }

    func refreshPermissions() {
        permissionState.refresh(
            microphonePermission: microphonePermission,
            accessibilityPermission: accessibilityPermission,
            startupPermission: startupPermission
        )
    }

    func requestMicrophoneAccess() async {
        _ = await microphonePermission.requestAccess()
        refreshPermissions()
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
            try hotkeyService.register(hotkeyRegistrations())
            if case .hotkeyUnavailable = appState.lastError {
                appState.lastError = nil
            }
        } catch {
            appState.lastError = .hotkeyUnavailable(details: error.localizedDescription)
        }
    }

    private func hotkeyRegistrations() throws -> [HotkeyRegistration] {
        if
            let toggleHotkey = settings.toggleHotkey,
            let pushToTalkHotkey = settings.pushToTalkHotkey,
            toggleHotkey == pushToTalkHotkey
        {
            throw AppError.hotkeyUnavailable(details: "Toggle and push-to-talk cannot use the same hotkey.")
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

        return registrations
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
        }
    }

    private func handlePushToTalkPressed() async {
        guard recordingTrigger == nil, appState.state.canStartRecording else {
            return
        }

        recordingTrigger = .pushToTalk
        await pipeline.startRecording()

        if !appState.state.isRecording {
            recordingTrigger = nil
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
}

private extension DictationState {
    var canStartRecording: Bool {
        switch self {
        case .idle, .completed, .failed, .cancelled:
            true
        case .recording, .transcribing, .cleaning, .inserting:
            false
        }
    }

    var isRecording: Bool {
        if case .recording = self {
            return true
        }

        return false
    }
}
