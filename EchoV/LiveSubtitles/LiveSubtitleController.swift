import Foundation

@MainActor
final class LiveSubtitleController {
    private static let transcriptionTimeoutSeconds: UInt64 = 60
    private static let postProcessingTimeoutSeconds: UInt64 = 3
    private static let catchUpQueueDepth = 1
    private static let catchUpDelaySeconds: TimeInterval = 5

    let store: LiveSubtitleStore

    private let capture: LiveSubtitleAudioCapture
    private let normalizer: AudioNormalizer
    private var asrEngine: any ASREngine
    private var textGenerationEngine: any LocalTextGenerationEngine
    private let selectedAudioDeviceID: @MainActor () -> String?
    private let chunkConfiguration: @MainActor () -> LiveSubtitleChunkConfiguration
    private let mode: @MainActor () -> LiveSubtitleMode
    private let targetLanguage: @MainActor () -> String
    private let showsRawWhileProcessing: @MainActor () -> Bool
    private let holdSeconds: @MainActor () -> TimeInterval

    private var pendingChunks: [LiveSubtitleAudioChunk] = []
    private var processingTask: Task<Void, Never>?
    private var clearTask: Task<Void, Never>?
    private var latestCapturedEnd: Date?
    private var latestDisplayedEnd: Date?
    private var onStopped: @MainActor () -> Void = {}

    init(
        store: LiveSubtitleStore,
        capture: LiveSubtitleAudioCapture,
        normalizer: AudioNormalizer = AudioNormalizer(),
        asrEngine: any ASREngine,
        textGenerationEngine: any LocalTextGenerationEngine,
        selectedAudioDeviceID: @escaping @MainActor () -> String?,
        chunkConfiguration: @escaping @MainActor () -> LiveSubtitleChunkConfiguration,
        mode: @escaping @MainActor () -> LiveSubtitleMode,
        targetLanguage: @escaping @MainActor () -> String,
        showsRawWhileProcessing: @escaping @MainActor () -> Bool,
        holdSeconds: @escaping @MainActor () -> TimeInterval
    ) {
        self.store = store
        self.capture = capture
        self.normalizer = normalizer
        self.asrEngine = asrEngine
        self.textGenerationEngine = textGenerationEngine
        self.selectedAudioDeviceID = selectedAudioDeviceID
        self.chunkConfiguration = chunkConfiguration
        self.mode = mode
        self.targetLanguage = targetLanguage
        self.showsRawWhileProcessing = showsRawWhileProcessing
        self.holdSeconds = holdSeconds
    }

    func setASREngine(_ asrEngine: any ASREngine) {
        self.asrEngine = asrEngine
    }

    func setTextGenerationEngine(_ textGenerationEngine: any LocalTextGenerationEngine) {
        self.textGenerationEngine = textGenerationEngine
    }

    func setOnStopped(_ onStopped: @escaping @MainActor () -> Void) {
        self.onStopped = onStopped
    }

    func start() async {
        guard !store.isRunning else {
            return
        }

        clearTask?.cancel()
        pendingChunks.removeAll()
        latestCapturedEnd = nil
        latestDisplayedEnd = nil
        store.clearSubtitles()
        store.start(detail: "Loading Parakeet...")

        do {
            try await asrEngine.prepare()
            store.updateStatus(audioSourceStatusDetail)
            try await capture.start(
                configuration: LiveSubtitleAudioCaptureConfiguration(
                    selectedAudioDeviceID: selectedAudioDeviceID(),
                    chunking: chunkConfiguration()
                ),
                onChunkReady: { [weak self] chunk in
                    self?.enqueue(chunk)
                },
                onError: { [weak self] error in
                    self?.fail(error)
                }
            )
        } catch let error as AppError {
            fail(error)
        } catch {
            fail(.recordingFailed(details: error.localizedDescription))
        }
    }

    func stop(notify: Bool = true) {
        capture.stop()
        processingTask?.cancel()
        processingTask = nil
        clearTask?.cancel()
        clearTask = nil
        pendingChunks.forEach(deleteChunk)
        pendingChunks.removeAll()
        latestCapturedEnd = nil
        latestDisplayedEnd = nil
        store.clearSubtitles()
        store.stop()
        if notify {
            onStopped()
        }
    }

    private func enqueue(_ chunk: LiveSubtitleAudioChunk) {
        guard store.isRunning else {
            deleteChunk(chunk)
            return
        }

        latestCapturedEnd = chunk.endedAt
        pendingChunks.append(chunk)
        store.updateQueueDepth(pendingChunks.count)
        publishDelay()

        if processingTask == nil {
            processingTask = Task { [weak self] in
                await self?.processLoop()
            }
        }
    }

    private func processLoop() async {
        defer {
            processingTask = nil
            store.updateQueueDepth(pendingChunks.count)
        }

        while store.isRunning, !Task.isCancelled {
            guard !pendingChunks.isEmpty else {
                break
            }

            let chunk = pendingChunks.removeFirst()
            store.updateQueueDepth(pendingChunks.count)
            await process(chunk)
        }
    }

    private func process(_ chunk: LiveSubtitleAudioChunk) async {
        let normalizedAudioURL: URL

        do {
            store.updateStatus("Transcribing live audio...")
            normalizedAudioURL = try await normalizer.normalize(chunk.fileURL)
            let transcript = try await withTimeout(seconds: Self.transcriptionTimeoutSeconds) {
                try await self.asrEngine.transcribe(audioURL: normalizedAudioURL, options: ASROptions())
            }
            let rawText = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawText.isEmpty else {
                deleteChunk(chunk)
                return
            }

            await publish(rawText: rawText, chunk: chunk)
        } catch let error as AppError {
            handleChunkError(error)
        } catch {
            handleChunkError(.transcriptionFailed(details: error.localizedDescription))
        }

        deleteChunk(chunk)
    }

    private func publish(rawText: String, chunk: LiveSubtitleAudioChunk) async {
        let subtitleMode = mode()
        let shouldAttemptPostProcessing = subtitleMode.requiresPostProcessing
        let skipPostProcessing = shouldSkipPostProcessing()
        let showRawFirst = !shouldAttemptPostProcessing || showsRawWhileProcessing() || skipPostProcessing

        if showRawFirst {
            latestDisplayedEnd = chunk.endedAt
            store.showSubtitle(
                rawText,
                chunkID: chunk.id,
                isFinal: !shouldAttemptPostProcessing || skipPostProcessing
            )
            scheduleClear()
            publishDelay()
        }

        guard shouldAttemptPostProcessing, !skipPostProcessing else {
            if skipPostProcessing {
                store.updateStatus("Catching up with raw captions.")
            } else {
                store.updateStatus(audioSourceStatusDetail)
            }
            return
        }

        do {
            store.setPostProcessing(true)
            store.updateStatus(subtitleMode == .translatedSubtitles ? "Translating subtitle..." : "Cleaning subtitle...")
            let postProcessor = LiveSubtitlePostProcessor(textGenerationEngine: textGenerationEngine)
            let processedText = try await withTimeout(seconds: Self.postProcessingTimeoutSeconds) {
                try await postProcessor.process(
                    text: rawText,
                    mode: subtitleMode,
                    targetLanguage: self.targetLanguage()
                )
            }
            store.setPostProcessing(false)

            guard !processedText.isEmpty else {
                if !showRawFirst {
                    store.showSubtitle(rawText, chunkID: chunk.id, isFinal: true)
                }
                return
            }

            latestDisplayedEnd = chunk.endedAt
            store.showSubtitle(processedText, chunkID: chunk.id, isFinal: true)
            scheduleClear()
            publishDelay()
            store.updateStatus(audioSourceStatusDetail)
        } catch let error as AppError {
            store.setPostProcessing(false)
            if !showRawFirst {
                latestDisplayedEnd = chunk.endedAt
                store.showSubtitle(rawText, chunkID: chunk.id, isFinal: true)
                scheduleClear()
                publishDelay()
            }
            store.updateStatus(postProcessingFallbackDetail(for: error))
        } catch {
            store.setPostProcessing(false)
            if !showRawFirst {
                latestDisplayedEnd = chunk.endedAt
                store.showSubtitle(rawText, chunkID: chunk.id, isFinal: true)
                scheduleClear()
                publishDelay()
            }
            store.updateStatus("Subtitle cleanup failed; showing raw captions.")
        }
    }

    private func shouldSkipPostProcessing() -> Bool {
        pendingChunks.count >= Self.catchUpQueueDepth || currentDelaySeconds >= Self.catchUpDelaySeconds
    }

    private func publishDelay() {
        let delay = currentDelaySeconds
        store.updateDelay(
            delay,
            isCatchingUp: pendingChunks.count >= Self.catchUpQueueDepth || delay >= Self.catchUpDelaySeconds
        )
    }

    private var currentDelaySeconds: TimeInterval {
        guard let latestCapturedEnd else {
            return 0
        }

        guard let latestDisplayedEnd else {
            return max(0, Date().timeIntervalSince(latestCapturedEnd))
        }

        return max(0, latestCapturedEnd.timeIntervalSince(latestDisplayedEnd))
    }

    private func handleChunkError(_ error: AppError) {
        switch error {
        case .modelNotSelected, .modelLoadFailed, .microphonePermissionDenied:
            fail(error)
        default:
            store.updateStatus(error.userMessage)
        }
    }

    private func fail(_ error: AppError) {
        capture.stop()
        processingTask?.cancel()
        processingTask = nil
        pendingChunks.forEach(deleteChunk)
        pendingChunks.removeAll()
        store.fail(error)
        onStopped()
    }

    private func postProcessingFallbackDetail(for error: AppError) -> String {
        switch error {
        case .cleanupModelNotConfigured:
            "Prime model unavailable; showing raw captions."
        default:
            "\(error.userMessage) Showing raw captions."
        }
    }

    private func scheduleClear() {
        clearTask?.cancel()
        let lastUpdatedAt = store.lastUpdatedAt
        let holdSeconds = holdSeconds()
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(max(0.5, holdSeconds) * 1000)))
            await MainActor.run {
                guard let self, self.store.lastUpdatedAt == lastUpdatedAt else {
                    return
                }
                self.store.clearSubtitles()
            }
        }
    }

    private var audioSourceStatusDetail: String {
        guard let selectedID = selectedAudioDeviceID(), !selectedID.isEmpty else {
            return "Listening to system default input."
        }

        let device = MicrophoneDeviceCatalog.inputDevices().first { $0.id == selectedID }
        return "Listening to \(device?.name ?? "selected input")."
    }

    private func deleteChunk(_ chunk: LiveSubtitleAudioChunk) {
        try? FileManager.default.removeItem(at: chunk.fileURL)
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
                throw AppError.cleanupFailed(details: "Live subtitle operation timed out.")
            }

            guard let result = try await group.next() else {
                throw AppError.cleanupFailed(details: "Live subtitle operation timed out.")
            }

            group.cancelAll()
            return result
        }
    }
}
