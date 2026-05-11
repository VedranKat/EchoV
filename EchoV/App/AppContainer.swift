import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {
    let appState: AppState
    let settings: AppSettings
    let pipeline: DictationPipeline
    let microphonePermission: MicrophonePermissionService
    let accessibilityPermission: AccessibilityPermissionService
    let modelStore: ModelStore
    let historyStore: TranscriptHistoryStore
    let temporaryAudioStore: TemporaryAudioStore
    let licensesStore: LicensesStore

    private let hotkeyService: any HotkeyService

    private init(
        appState: AppState,
        settings: AppSettings,
        pipeline: DictationPipeline,
        microphonePermission: MicrophonePermissionService,
        accessibilityPermission: AccessibilityPermissionService,
        modelStore: ModelStore,
        historyStore: TranscriptHistoryStore,
        temporaryAudioStore: TemporaryAudioStore,
        licensesStore: LicensesStore,
        hotkeyService: any HotkeyService
    ) {
        self.appState = appState
        self.settings = settings
        self.pipeline = pipeline
        self.microphonePermission = microphonePermission
        self.accessibilityPermission = accessibilityPermission
        self.modelStore = modelStore
        self.historyStore = historyStore
        self.temporaryAudioStore = temporaryAudioStore
        self.licensesStore = licensesStore
        self.hotkeyService = hotkeyService
    }

    static func bootstrap() -> AppContainer {
        let settings = AppSettings()
        let appState = AppState()
        let microphonePermission = MicrophonePermissionService()
        let accessibilityPermission = AccessibilityPermissionService()
        let modelStore = ModelStore()
        let historyStore = TranscriptHistoryStore()
        let temporaryAudioStore = TemporaryAudioStore()
        let licensesStore = LicensesStore()

        let pipeline = DictationPipeline(
            appState: appState,
            recorder: AVFoundationAudioRecorder(microphonePermission: microphonePermission),
            normalizer: AudioNormalizer(),
            asrEngine: UnconfiguredASREngine(),
            cleanupEngine: NoOpTextCleanupEngine(),
            insertion: PasteInsertionService(accessibilityPermission: accessibilityPermission),
            history: historyStore,
            temporaryAudioStore: temporaryAudioStore,
            isHistoryEnabled: { settings.isHistoryEnabled },
            shouldDeleteTemporaryAudio: { settings.shouldDeleteTemporaryAudio },
            onStateChanged: { appState.notifyStatusChanged() }
        )

        return AppContainer(
            appState: appState,
            settings: settings,
            pipeline: pipeline,
            microphonePermission: microphonePermission,
            accessibilityPermission: accessibilityPermission,
            modelStore: modelStore,
            historyStore: historyStore,
            temporaryAudioStore: temporaryAudioStore,
            licensesStore: licensesStore,
            hotkeyService: CarbonHotkeyService()
        )
    }

    func start() {
        Task {
            await historyStore.load()
            await modelStore.restoreSelection()
            configureASREngineFromSelectedModel()
        }

        do {
            try hotkeyService.register(settings.hotkey) { [weak pipeline] in
                Task {
                    await pipeline?.toggleRecording()
                }
            }
        } catch {
            appState.lastError = .hotkeyUnavailable(details: error.localizedDescription)
        }
    }

    func stop() {
        hotkeyService.unregister()
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
        modelStore.clearSelection()
        pipeline.setASREngine(UnconfiguredASREngine())
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
}
