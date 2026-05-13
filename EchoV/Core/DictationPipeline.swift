import Foundation

@MainActor
final class DictationPipeline {
    private static let transcriptionTimeoutSeconds: UInt64 = 300

    private let appState: AppState
    private let recorder: any AudioRecorder
    private let normalizer: AudioNormalizer
    private var asrEngine: any ASREngine
    private var cleanupEngine: any TextCleanupEngine
    private let insertion: any TextInsertionService
    private let history: TranscriptHistoryStore
    private let temporaryAudioStore: TemporaryAudioStore
    private let isHistoryEnabled: @MainActor () -> Bool
    private let shouldDeleteTemporaryAudio: @MainActor () -> Bool
    private let isPostProcessingEnabled: @MainActor () -> Bool
    private let onStateChanged: @MainActor () -> Void

    private var currentRecording: RecordedAudio?
    private var lastNormalizedAudioURL: URL?

    init(
        appState: AppState,
        recorder: any AudioRecorder,
        normalizer: AudioNormalizer,
        asrEngine: any ASREngine,
        cleanupEngine: any TextCleanupEngine,
        insertion: any TextInsertionService,
        history: TranscriptHistoryStore,
        temporaryAudioStore: TemporaryAudioStore,
        isHistoryEnabled: @escaping @MainActor () -> Bool,
        shouldDeleteTemporaryAudio: @escaping @MainActor () -> Bool,
        isPostProcessingEnabled: @escaping @MainActor () -> Bool,
        onStateChanged: @escaping @MainActor () -> Void = {}
    ) {
        self.appState = appState
        self.recorder = recorder
        self.normalizer = normalizer
        self.asrEngine = asrEngine
        self.cleanupEngine = cleanupEngine
        self.insertion = insertion
        self.history = history
        self.temporaryAudioStore = temporaryAudioStore
        self.isHistoryEnabled = isHistoryEnabled
        self.shouldDeleteTemporaryAudio = shouldDeleteTemporaryAudio
        self.isPostProcessingEnabled = isPostProcessingEnabled
        self.onStateChanged = onStateChanged
    }

    func setASREngine(_ asrEngine: any ASREngine) {
        var engine = asrEngine
        engine.onStatusUpdate = { [weak self] detail in
            Task { @MainActor in
                self?.appState.lastDetail = detail
                self?.onStateChanged()
            }
        }
        self.asrEngine = engine
    }

    func prepareASR() async throws {
        try await asrEngine.prepare()
    }

    func setCleanupEngine(_ cleanupEngine: any TextCleanupEngine) {
        let previousCleanupEngine = self.cleanupEngine
        self.cleanupEngine = cleanupEngine

        Task {
            await previousCleanupEngine.shutdown()
        }
    }

    func shutdownCleanupEngine() async {
        let previousCleanupEngine = cleanupEngine
        cleanupEngine = GemmaPrimeTextCleanupEngine(
            textGenerationEngine: UnconfiguredLocalTextGenerationEngine()
        )
        await previousCleanupEngine.shutdown()
    }

    func prepareCleanup() async throws {
        try await cleanupEngine.prepare()
    }

    func refreshStatus() {
        onStateChanged()
    }

    func toggleRecording() async {
        switch appState.state {
        case .recording:
            await stopTranscribeAndInsert()
        default:
            await startRecording()
        }
    }

    func startRecording() async {
        do {
            currentRecording = try await recorder.start()
            setState(.recording(startedAt: Date()))
            appState.lastError = nil
        } catch let error as AppError {
            fail(error)
        } catch {
            fail(.recordingFailed(details: error.localizedDescription))
        }
    }

    func stopTranscribeAndInsert() async {
        do {
            let recordedAudio = try await recorder.stop()
            currentRecording = recordedAudio

            setState(.transcribing(status: "Preparing audio..."))
            let normalizedAudioURL = try await normalizer.normalize(recordedAudio.fileURL)
            lastNormalizedAudioURL = normalizedAudioURL
            appState.lastDetail = audioDetail(for: normalizedAudioURL)
            setState(.transcribing(status: "Loading model / transcribing..."))
            let transcript = try await withTimeout(seconds: Self.transcriptionTimeoutSeconds) {
                try await self.asrEngine.transcribe(
                    audioURL: normalizedAudioURL,
                    options: ASROptions()
                )
            }

            let cleanedText: CleanedText
            if isPostProcessingEnabled() {
                setState(.cleaning)
                cleanedText = try await cleanupEngine.clean(transcript)
            } else {
                cleanedText = CleanedText(text: transcript.text)
            }

            setState(.inserting)
            _ = try await insertion.insert(cleanedText.text)

            let finalTranscript = Transcript(
                text: cleanedText.text,
                segments: transcript.segments,
                createdAt: transcript.createdAt,
                duration: transcript.duration
            )
            if isHistoryEnabled() {
                await history.append(finalTranscript)
            }
            setState(.completed(finalTranscript))
            cleanupTemporaryAudio(recordedAudioURL: recordedAudio.fileURL, normalizedAudioURL: normalizedAudioURL)
            currentRecording = nil
            lastNormalizedAudioURL = nil
            temporaryAudioStore.clearFailedAudio()
        } catch let error as AppError {
            rememberFailedAudio()
            fail(error)
        } catch {
            rememberFailedAudio()
            fail(.unknown(details: error.localizedDescription))
        }
    }

    private func fail(_ error: AppError) {
        appState.lastError = error
        setState(.failed(error))
    }

    private func setState(_ state: DictationState) {
        appState.state = state
        onStateChanged()
    }

    private func audioDetail(for url: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes?[.size] as? Int64 ?? 0
        return "Audio: \(url.lastPathComponent), \(size) bytes"
    }

    private func cleanupTemporaryAudio(recordedAudioURL: URL, normalizedAudioURL: URL) {
        guard shouldDeleteTemporaryAudio() else {
            return
        }

        temporaryAudioStore.delete([recordedAudioURL, normalizedAudioURL])
    }

    private func rememberFailedAudio() {
        if let lastNormalizedAudioURL {
            temporaryAudioStore.rememberFailedAudio(lastNormalizedAudioURL)
            return
        }

        if let currentRecording {
            temporaryAudioStore.rememberFailedAudio(currentRecording.fileURL)
        }
    }

    private func withTimeout<T: Sendable>(
        seconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw AppError.transcriptionTimedOut
            }

            guard let result = try await group.next() else {
                throw AppError.transcriptionTimedOut
            }

            group.cancelAll()
            return result
        }
    }
}
