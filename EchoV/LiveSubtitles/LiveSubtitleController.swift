import Foundation

@MainActor
final class LiveSubtitleController {
    private static let transcriptionTimeoutSeconds: UInt64 = 60

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
    private var displayTask: Task<Void, Never>?
    private var displayTaskID: UUID?
    private var displayQueue: [QueuedLiveSubtitleDisplayUnit] = []
    private var postProcessingTasks: [UUID: Task<Void, Never>] = [:]
    private var activeDisplayChunkID: UUID?
    private var isProcessingChunk = false
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
        cancelPostProcessingTasks()
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
        displayTask?.cancel()
        displayTask = nil
        displayTaskID = nil
        cancelPostProcessingTasks()
        displayQueue.removeAll()
        activeDisplayChunkID = nil
        isProcessingChunk = false
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
        isProcessingChunk = true
        defer {
            isProcessingChunk = false
        }

        do {
            store.updateStatus("Transcribing live audio...")
            normalizedAudioURL = try await normalizer.normalize(chunk.fileURL)
            let transcript = try await withTimeout(
                seconds: Self.transcriptionTimeoutSeconds,
                timeoutError: .transcriptionTimedOut
            ) {
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
        let skipPostProcessing = shouldSkipPostProcessing(mode: subtitleMode)
        let showRawFirst = LiveSubtitlePostProcessingPolicy.shouldDisplaySourceCaptionBeforeProcessing(
            mode: subtitleMode,
            showsRawWhileProcessing: showsRawWhileProcessing(),
            skipPostProcessing: skipPostProcessing
        )

        if showRawFirst {
            displaySubtitle(
                rawText,
                chunk: chunk,
                isFinal: !shouldAttemptPostProcessing || skipPostProcessing
            )
        }

        guard shouldAttemptPostProcessing, !skipPostProcessing else {
            if skipPostProcessing {
                DiagnosticLog.write(
                    "Live subtitle post-processing skipped mode=\(subtitleMode.rawValue) pending=\(pendingChunks.count) delay=\(String(format: "%.2f", currentDelaySeconds))"
                )
                store.updateStatus("Catching up with raw captions.")
            } else {
                store.updateStatus(audioSourceStatusDetail)
            }
            return
        }

        if showRawFirst || subtitleMode == .translatedSubtitles {
            startPostProcessing(rawText: rawText, chunk: chunk, mode: subtitleMode, showRawFirst: showRawFirst)
        } else {
            await finishPostProcessing(rawText: rawText, chunk: chunk, mode: subtitleMode, showRawFirst: false)
        }
    }

    private func startPostProcessing(
        rawText: String,
        chunk: LiveSubtitleAudioChunk,
        mode: LiveSubtitleMode,
        showRawFirst: Bool
    ) {
        postProcessingTasks[chunk.id]?.cancel()
        store.setPostProcessing(true)
        store.updateStatus(postProcessingStatusDetail(for: mode))

        let task = Task { [weak self] in
            guard let self else {
                return
            }
            await self.finishPostProcessing(
                rawText: rawText,
                chunk: chunk,
                mode: mode,
                showRawFirst: showRawFirst
            )
        }
        postProcessingTasks[chunk.id] = task
    }

    private func finishPostProcessing(
        rawText: String,
        chunk: LiveSubtitleAudioChunk,
        mode: LiveSubtitleMode,
        showRawFirst: Bool
    ) async {
        do {
            if !showRawFirst {
                store.setPostProcessing(true)
                store.updateStatus(postProcessingStatusDetail(for: mode))
            }

            let postProcessor = LiveSubtitlePostProcessor(textGenerationEngine: textGenerationEngine)
            DiagnosticLog.write(
                "Live subtitle post-processing started mode=\(mode.rawValue) engine=\(textGenerationEngine.displayName) chars=\(rawText.count)"
            )
            let processedText = try await withTimeout(
                seconds: LiveSubtitlePostProcessingPolicy.timeoutSeconds(for: mode),
                timeoutError: .cleanupFailed(details: "Live subtitle post-processing timed out.")
            ) {
                try await postProcessor.process(
                    text: rawText,
                    mode: mode,
                    targetLanguage: self.targetLanguage()
                )
            }

            completePostProcessingTask(for: chunk.id)
            guard !Task.isCancelled else {
                return
            }
            DiagnosticLog.write(
                "Live subtitle post-processing completed mode=\(mode.rawValue) engine=\(textGenerationEngine.displayName) chars=\(processedText.count)"
            )

            guard !processedText.isEmpty else {
                if !showRawFirst, LiveSubtitlePostProcessingPolicy.allowsSourceCaptionFallback(for: mode) {
                    displaySubtitle(rawText, chunk: chunk, isFinal: true)
                }
                updateStatusAfterPostProcessingFinished(emptyPostProcessingDetail(for: mode))
                return
            }

            guard shouldDisplayProcessedSubtitle(for: chunk, mode: mode) else {
                DiagnosticLog.write(
                    "Live subtitle post-processing skipped stale result mode=\(mode.rawValue) delay=\(String(format: "%.2f", latestCapturedEnd?.timeIntervalSince(chunk.endedAt) ?? 0))"
                )
                updateStatusAfterPostProcessingFinished(stalePostProcessingDetail(for: mode))
                return
            }

            displaySubtitle(processedText, chunk: chunk, isFinal: true)
            updateStatusAfterPostProcessingFinished(audioSourceStatusDetail)
        } catch let error as AppError {
            completePostProcessingTask(for: chunk.id)
            guard !Task.isCancelled else {
                return
            }
            DiagnosticLog.write(
                "Live subtitle post-processing fallback: \(error.userMessage) details=\(error.technicalDetails ?? "none")"
            )
            if !showRawFirst, LiveSubtitlePostProcessingPolicy.allowsSourceCaptionFallback(for: mode) {
                displaySubtitle(rawText, chunk: chunk, isFinal: true)
            }
            updateStatusAfterPostProcessingFinished(postProcessingFallbackDetail(for: mode, error: error))
        } catch {
            completePostProcessingTask(for: chunk.id)
            guard !Task.isCancelled else {
                return
            }
            DiagnosticLog.write("Live subtitle post-processing fallback: \(error.localizedDescription)")
            if !showRawFirst, LiveSubtitlePostProcessingPolicy.allowsSourceCaptionFallback(for: mode) {
                displaySubtitle(rawText, chunk: chunk, isFinal: true)
            }
            updateStatusAfterPostProcessingFinished(genericPostProcessingFallbackDetail(for: mode))
        }
    }

    private func displaySubtitle(_ text: String, chunk: LiveSubtitleAudioChunk, isFinal: Bool) {
        clearTask?.cancel()
        clearTask = nil

        let units = LiveSubtitleDisplayTiming.displayUnits(
            for: text,
            spokenDuration: chunk.duration,
            baseHoldSeconds: holdSeconds()
        ).enumerated().map { unitIndex, unit in
            QueuedLiveSubtitleDisplayUnit(
                chunkID: chunk.id,
                unitIndex: unitIndex,
                chunkStartedAt: chunk.startedAt,
                chunkEndedAt: chunk.endedAt,
                unit: unit,
                isFinal: isFinal
            )
        }
        guard !units.isEmpty else {
            return
        }

        let shouldReplaceActiveChunk = activeDisplayChunkID == chunk.id
        let replacementIndex = displayQueue.firstIndex { $0.chunkID == chunk.id }
        displayQueue.removeAll { $0.chunkID == chunk.id }
        if shouldReplaceActiveChunk {
            displayQueue.insert(contentsOf: units, at: 0)
            displayTask?.cancel()
            displayTask = nil
            displayTaskID = nil
        } else if let replacementIndex {
            displayQueue.insert(contentsOf: units, at: min(replacementIndex, displayQueue.count))
        } else {
            displayQueue.append(contentsOf: units)
        }
        trimDisplayQueueForSync(latestChunkEnd: chunk.endedAt)

        startDisplayTaskIfNeeded()
    }

    private func startDisplayTaskIfNeeded() {
        guard displayTask == nil else {
            return
        }

        let taskID = UUID()
        displayTaskID = taskID
        displayTask = Task { [weak self] in
            await self?.runDisplayLoop(taskID: taskID)
        }
    }

    private func runDisplayLoop(taskID: UUID) async {
        var idleClearDelay: TimeInterval = 0.1

        while !Task.isCancelled {
            guard let unit = nextDisplayUnit() else {
                break
            }

            store.showSubtitle(
                unit.unit.text,
                chunkID: unit.chunkID,
                lineID: LiveSubtitleLineID(chunkID: unit.chunkID, unitIndex: unit.unitIndex),
                isFinal: unit.isFinal
            )
            latestDisplayedEnd = unit.chunkEndedAt
            publishDelay()
            let activeDwell = await sleepForDisplay(unit)
            let remainingHold = max(0, unit.effectiveHoldSeconds - activeDwell)
            if let nextSameChunkIndex = displayQueue.firstIndex(where: { $0.chunkID == unit.chunkID }) {
                displayQueue[nextSameChunkIndex].extraHoldSeconds += remainingHold
                idleClearDelay = 0.1
            } else {
                idleClearDelay = max(0.1, remainingHold)
            }
        }

        guard displayTaskID == taskID else {
            return
        }

        activeDisplayChunkID = nil
        displayTask = nil
        displayTaskID = nil
        if displayQueue.isEmpty {
            scheduleClear(after: idleClearDelay)
        } else {
            startDisplayTaskIfNeeded()
        }
    }

    private func nextDisplayUnit() -> QueuedLiveSubtitleDisplayUnit? {
        if let latestCapturedEnd {
            trimDisplayQueueForSync(latestChunkEnd: latestCapturedEnd)
        }

        guard !displayQueue.isEmpty else {
            activeDisplayChunkID = nil
            return nil
        }

        let unit = displayQueue.removeFirst()
        activeDisplayChunkID = unit.chunkID
        return unit
    }

    private func sleepForDisplay(_ unit: QueuedLiveSubtitleDisplayUnit) async -> TimeInterval {
        let shownAt = Date()

        while !Task.isCancelled {
            let elapsed = Date().timeIntervalSince(shownAt)
            let target = max(0.2, displayDwellSeconds(for: unit))
            guard elapsed < target else {
                break
            }

            let remaining = max(0.05, min(0.10, target - elapsed))
            try? await Task.sleep(for: .milliseconds(Int(remaining * 1000)))
        }

        return max(0, Date().timeIntervalSince(shownAt))
    }

    private func displayDwellSeconds(for unit: QueuedLiveSubtitleDisplayUnit) -> TimeInterval {
        LiveSubtitleDisplaySyncPolicy.dwellSeconds(
            for: unit.unit,
            hasBacklog: hasNewerDisplayBacklog(after: unit),
            captionEndLagSeconds: max(0, Date().timeIntervalSince(unit.chunkEndedAt))
        )
    }

    private func hasNewerDisplayBacklog(after unit: QueuedLiveSubtitleDisplayUnit) -> Bool {
        displayQueue.contains { $0.chunkEndedAt > unit.chunkEndedAt }
    }

    private func trimDisplayQueueForSync(latestChunkEnd: Date) {
        displayQueue.removeAll {
            latestChunkEnd.timeIntervalSince($0.chunkEndedAt) > LiveSubtitleDisplaySyncPolicy.maximumQueuedSubtitleLagSeconds
        }

        while displayQueue.count > LiveSubtitleDisplaySyncPolicy.maximumQueuedDisplayUnits {
            displayQueue.removeFirst()
        }
    }

    private func shouldSkipPostProcessing(mode: LiveSubtitleMode) -> Bool {
        LiveSubtitlePostProcessingPolicy.shouldSkip(
            mode: mode,
            pendingChunkCount: pendingChunks.count,
            currentDelaySeconds: currentDelaySeconds
        )
    }

    private func publishDelay() {
        let delay = currentDelaySeconds
        store.updateDelay(
            delay,
            isCatchingUp: pendingChunks.count >= LiveSubtitlePostProcessingPolicy.catchUpQueueDepth
                || delay >= LiveSubtitlePostProcessingPolicy.catchUpDelaySeconds
        )
    }

    private func cancelPostProcessingTasks() {
        for task in postProcessingTasks.values {
            task.cancel()
        }
        postProcessingTasks.removeAll()
        store.setPostProcessing(false)
    }

    private func completePostProcessingTask(for chunkID: UUID) {
        postProcessingTasks[chunkID] = nil
        store.setPostProcessing(!postProcessingTasks.isEmpty)
    }

    private func shouldDisplayProcessedSubtitle(for chunk: LiveSubtitleAudioChunk, mode: LiveSubtitleMode) -> Bool {
        guard store.isRunning else {
            return false
        }

        guard let latestCapturedEnd else {
            return true
        }

        return latestCapturedEnd.timeIntervalSince(chunk.endedAt)
            <= LiveSubtitlePostProcessingPolicy.maximumProcessedSubtitleLagSeconds(for: mode)
    }

    private func updateStatusAfterPostProcessingFinished(_ detail: String) {
        guard postProcessingTasks.isEmpty else {
            return
        }
        store.updateStatus(detail)
    }

    private func postProcessingStatusDetail(for mode: LiveSubtitleMode) -> String {
        mode == .translatedSubtitles ? "Translating subtitle..." : "Cleaning subtitle..."
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
        displayTask?.cancel()
        displayTask = nil
        displayTaskID = nil
        cancelPostProcessingTasks()
        displayQueue.removeAll()
        activeDisplayChunkID = nil
        clearTask?.cancel()
        clearTask = nil
        isProcessingChunk = false
        pendingChunks.forEach(deleteChunk)
        pendingChunks.removeAll()
        store.fail(error)
        onStopped()
    }

    private func emptyPostProcessingDetail(for mode: LiveSubtitleMode) -> String {
        switch mode {
        case .rawCaptions:
            audioSourceStatusDetail
        case .cleanedCaptions:
            audioSourceStatusDetail
        case .translatedSubtitles:
            "Translation returned no text."
        }
    }

    private func stalePostProcessingDetail(for mode: LiveSubtitleMode) -> String {
        switch mode {
        case .rawCaptions:
            audioSourceStatusDetail
        case .cleanedCaptions:
            "Prime is behind; showing raw captions."
        case .translatedSubtitles:
            "Translation is behind."
        }
    }

    private func postProcessingFallbackDetail(for mode: LiveSubtitleMode, error: AppError) -> String {
        if mode == .translatedSubtitles {
            return "Translation unavailable."
        }

        return switch error {
        case .cleanupModelNotConfigured:
            "Prime model unavailable; showing raw captions."
        case .cleanupFailed(let details) where details.localizedCaseInsensitiveContains("timed out"):
            "Prime is behind; showing raw captions."
        case .cleanupFailed:
            "Prime could not finish this subtitle; showing raw captions."
        default:
            "Prime could not finish this subtitle; showing raw captions."
        }
    }

    private func genericPostProcessingFallbackDetail(for mode: LiveSubtitleMode) -> String {
        switch mode {
        case .rawCaptions:
            audioSourceStatusDetail
        case .cleanedCaptions:
            "Subtitle cleanup failed; showing raw captions."
        case .translatedSubtitles:
            "Translation unavailable."
        }
    }

    private func scheduleClear(after delay: TimeInterval) {
        clearTask?.cancel()
        let lastUpdatedAt = store.lastUpdatedAt
        clearTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(max(0.5, delay) * 1000)))
            await MainActor.run {
                guard let self, self.store.lastUpdatedAt == lastUpdatedAt else {
                    return
                }
                guard !self.shouldKeepSubtitleVisible else {
                    self.scheduleClear(after: 0.5)
                    return
                }
                self.store.clearSubtitles()
            }
        }
    }

    private var shouldKeepSubtitleVisible: Bool {
        store.isRunning && (isProcessingChunk || store.isPostProcessing || !pendingChunks.isEmpty || !displayQueue.isEmpty)
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
        timeoutError: AppError,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw timeoutError
            }

            guard let result = try await group.next() else {
                throw timeoutError
            }

            group.cancelAll()
            return result
        }
    }
}

private struct QueuedLiveSubtitleDisplayUnit: Sendable {
    let chunkID: UUID
    let unitIndex: Int
    let chunkStartedAt: Date
    let chunkEndedAt: Date
    let unit: LiveSubtitleDisplayUnit
    var extraHoldSeconds: TimeInterval = 0
    let isFinal: Bool

    var effectiveHoldSeconds: TimeInterval {
        unit.holdSeconds + extraHoldSeconds
    }
}
