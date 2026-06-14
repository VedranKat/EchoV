import Foundation

struct VoiceModeAssistantTurnResult: Sendable {
    let responseText: String
    let delivery: VoiceModeResponseDelivery
}

@MainActor
final class VoiceModeController {
    private static let wakePhraseSilenceTimeout: TimeInterval = 0.6
    private static let maximumWakePhraseDuration: TimeInterval = 2.4

    private let appState: AppState
    private let capture: VoiceActivatedAudioCapture
    private let pipeline: DictationPipeline
    private let speechOutput: any SpeechOutputService
    private let promptEndingPolicy: @MainActor () -> VoiceModePromptEndingPolicy
    private let noSpeechTimeoutSeconds: @MainActor () -> TimeInterval
    private let speechVoiceIdentifier: @MainActor () -> String
    private let speechSpeed: @MainActor () -> Double
    private var onAssistantSessionRequest: @MainActor (
        _ command: VoiceModeActivationCommand,
        _ userText: String
    ) async throws -> VoiceModeAssistantTurnResult
    private var selectedTextProvider: @MainActor () async -> String?
    private var promptPreview: @MainActor (
        _ command: VoiceModeActivationCommand,
        _ promptText: String,
        _ includesSelectionContext: Bool
    ) async -> String?
    private var playConfirmationCue: @MainActor (_ command: VoiceModeActivationCommand) async -> Void
    private var responseBackendValidationError: @MainActor () -> AppError?
    private var verifyCommandSpeaker: @MainActor (_ recordedAudio: RecordedAudio) async throws -> Bool
    private var verifyRequestSpeaker: @MainActor (_ recordedAudio: RecordedAudio) async throws -> Bool
    private var onCleanUpSelection: @MainActor () async -> Bool
    private var onStopped: @MainActor () -> Void
    private let onStateChanged: @MainActor () -> Void

    private var textGenerationEngine: any LocalTextGenerationEngine
    private var isEnabled = false
    private var promptSpeechStarted = false
    private var noSpeechTimeoutTask: Task<Void, Never>?
    private var activeOperationTask: Task<Void, Never>?
    private var speechPrewarmTask: Task<Void, Never>?
    private var runID = 0

    init(
        appState: AppState,
        capture: VoiceActivatedAudioCapture,
        pipeline: DictationPipeline,
        textGenerationEngine: any LocalTextGenerationEngine,
        speechOutput: any SpeechOutputService,
        promptEndingPolicy: @escaping @MainActor () -> VoiceModePromptEndingPolicy,
        noSpeechTimeoutSeconds: @escaping @MainActor () -> TimeInterval,
        speechVoiceIdentifier: @escaping @MainActor () -> String,
        speechSpeed: @escaping @MainActor () -> Double,
        onAssistantSessionRequest: @escaping @MainActor (
            _ command: VoiceModeActivationCommand,
            _ userText: String
        ) async throws -> VoiceModeAssistantTurnResult = { _, _ in
            throw AppError.voiceModeResponseNotConfigured
        },
        selectedTextProvider: @escaping @MainActor () async -> String? = { nil },
        promptPreview: @escaping @MainActor (
            _ command: VoiceModeActivationCommand,
            _ promptText: String,
            _ includesSelectionContext: Bool
        ) async -> String? = { _, promptText, _ in promptText },
        playConfirmationCue: @escaping @MainActor (_ command: VoiceModeActivationCommand) async -> Void = { _ in },
        responseBackendValidationError: @escaping @MainActor () -> AppError? = { nil },
        verifyCommandSpeaker: @escaping @MainActor (_ recordedAudio: RecordedAudio) async throws -> Bool = { _ in true },
        verifyRequestSpeaker: @escaping @MainActor (_ recordedAudio: RecordedAudio) async throws -> Bool = { _ in true },
        onCleanUpSelection: @escaping @MainActor () async -> Bool = { false },
        onStopped: @escaping @MainActor () -> Void,
        onStateChanged: @escaping @MainActor () -> Void
    ) {
        self.appState = appState
        self.capture = capture
        self.pipeline = pipeline
        self.textGenerationEngine = textGenerationEngine
        self.speechOutput = speechOutput
        self.promptEndingPolicy = promptEndingPolicy
        self.noSpeechTimeoutSeconds = noSpeechTimeoutSeconds
        self.speechVoiceIdentifier = speechVoiceIdentifier
        self.speechSpeed = speechSpeed
        self.onAssistantSessionRequest = onAssistantSessionRequest
        self.selectedTextProvider = selectedTextProvider
        self.promptPreview = promptPreview
        self.playConfirmationCue = playConfirmationCue
        self.responseBackendValidationError = responseBackendValidationError
        self.verifyCommandSpeaker = verifyCommandSpeaker
        self.verifyRequestSpeaker = verifyRequestSpeaker
        self.onCleanUpSelection = onCleanUpSelection
        self.onStopped = onStopped
        self.onStateChanged = onStateChanged
    }

    var availableSpeechVoices: [SpeechVoice] {
        speechOutput.availableVoices
    }

    func setOnStopped(_ onStopped: @escaping @MainActor () -> Void) {
        self.onStopped = onStopped
    }

    func setOnAssistantSessionRequest(
        _ onAssistantSessionRequest: @escaping @MainActor (
            _ command: VoiceModeActivationCommand,
            _ userText: String
        ) async throws -> VoiceModeAssistantTurnResult
    ) {
        self.onAssistantSessionRequest = onAssistantSessionRequest
    }

    func setOnCleanUpSelection(_ onCleanUpSelection: @escaping @MainActor () async -> Bool) {
        self.onCleanUpSelection = onCleanUpSelection
    }

    func setSelectedTextProvider(_ selectedTextProvider: @escaping @MainActor () async -> String?) {
        self.selectedTextProvider = selectedTextProvider
    }

    func setPromptPreview(
        _ promptPreview: @escaping @MainActor (
            _ command: VoiceModeActivationCommand,
            _ promptText: String,
            _ includesSelectionContext: Bool
        ) async -> String?
    ) {
        self.promptPreview = promptPreview
    }

    func setConfirmationCuePlayer(
        _ playConfirmationCue: @escaping @MainActor (_ command: VoiceModeActivationCommand) async -> Void
    ) {
        self.playConfirmationCue = playConfirmationCue
    }

    func setResponseBackendValidationError(_ responseBackendValidationError: @escaping @MainActor () -> AppError?) {
        self.responseBackendValidationError = responseBackendValidationError
    }

    func setVoiceGuardVerifiers(
        commandVerifier: @escaping @MainActor (_ recordedAudio: RecordedAudio) async throws -> Bool,
        requestVerifier: @escaping @MainActor (_ recordedAudio: RecordedAudio) async throws -> Bool
    ) {
        self.verifyCommandSpeaker = commandVerifier
        self.verifyRequestSpeaker = requestVerifier
    }

    func setTextGenerationEngine(_ textGenerationEngine: any LocalTextGenerationEngine) {
        self.textGenerationEngine = textGenerationEngine
    }

    func start() async {
        isEnabled = true
        prewarmSpeechOutputIfNeeded()
        await startWakeListening()
    }

    func activateManually(command: VoiceModeActivationCommand = .spoken) async {
        isEnabled = true
        cancelNoSpeechTimeout()
        cancelActiveOperation()
        capture.stop()
        speechOutput.stop()
        let selectedText = await selectedTextContext(for: command)
        await startPromptListening(command: command, selectedText: selectedText)
    }

    func stop() {
        let wasEnabled = isEnabled
        isEnabled = false
        invalidateCurrentRun()
        cancelNoSpeechTimeout()
        cancelActiveOperation()
        cancelSpeechPrewarm()
        capture.stop()
        speechOutput.stop()
        if wasEnabled {
            setState(.cancelled, detail: "Assistant stopped.")
        }
        onStopped()
    }

    private func startWakeListening(detail: String? = nil) async {
        guard isEnabled else {
            return
        }

        let runID = beginNewRun()
        cancelNoSpeechTimeout()
        appState.lastError = nil
        setState(
            .voiceModeWakeListening,
            detail: detail ?? "Assistant is listening for Computer, Computer refresh, Computer text, Continue, or Computer cleanup."
        )

        do {
            try await capture.start(
                configuration: VoiceGateCaptureConfiguration(
                    silenceTimeoutSeconds: Self.wakePhraseSilenceTimeout,
                    sensitivity: .medium
                ),
                onSpeechStarted: { [weak self] _ in
                    guard let self, self.isCurrentRun(runID) else {
                        return
                    }

                    self.appState.lastDetail = "Checking activation phrase..."
                    self.setState(.voiceModeCheckingWakePhrase)
                },
                onUtteranceEnded: { [weak self] recordedAudio in
                    self?.activeOperationTask = Task { @MainActor [weak self] in
                        await self?.handleWakePhraseCandidate(recordedAudio, runID: runID)
                    }
                },
                onError: { [weak self] error in
                    guard let self, self.isCurrentRun(runID) else {
                        return
                    }

                    self.fail(error)
                }
            )
        } catch let error as AppError {
            guard isCurrentRun(runID) else {
                return
            }
            fail(error)
        } catch {
            guard isCurrentRun(runID) else {
                return
            }
            fail(.recordingFailed(details: error.localizedDescription))
        }
    }

    private func handleWakePhraseCandidate(_ recordedAudio: RecordedAudio, runID: Int) async {
        guard isEnabled, isCurrentRun(runID) else {
            deleteTemporaryAudio(recordedAudio)
            return
        }

        guard recordedAudio.duration <= Self.maximumWakePhraseDuration else {
            appState.recordRejectedWakeTranscript(VoiceModeRejectedWakeTranscript(
                text: "",
                reason: .durationExceeded
            ))
            deleteTemporaryAudio(recordedAudio)
            await startWakeListening()
            return
        }

        do {
            guard try await verifyCommandSpeaker(recordedAudio) else {
                deleteTemporaryAudio(recordedAudio)
                guard isEnabled, isCurrentRun(runID) else {
                    return
                }

                await startWakeListening(detail: "Different voice ignored. Listening again.")
                return
            }

            guard isEnabled, isCurrentRun(runID) else {
                deleteTemporaryAudio(recordedAudio)
                return
            }

            let transcript = try await pipeline.transcribeForVoiceMode(
                recordedAudio,
                status: "Checking activation phrase..."
            )

            guard isEnabled, isCurrentRun(runID) else {
                return
            }

            if let command = WakePhraseMatcher.activationCommand(for: transcript.text) {
                if command == .cleanUpSelection {
                    await playConfirmationCue(command)
                    await cleanUpSelection()
                    return
                }

                let selectedText = await selectedTextContext(for: command)
                await startPromptListening(command: command, selectedText: selectedText)
            } else {
                let rejectedText = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !rejectedText.isEmpty {
                    appState.recordRejectedWakeTranscript(VoiceModeRejectedWakeTranscript(
                        text: rejectedText,
                        reason: .notExactActivationCommand
                    ))
                }
                await startWakeListening()
            }
        } catch let error as AppError {
            guard isCurrentRun(runID) else {
                return
            }
            fail(error)
        } catch {
            guard isCurrentRun(runID) else {
                return
            }
            fail(.unknown(details: error.localizedDescription))
        }
    }

    private func startPromptListening(command: VoiceModeActivationCommand, selectedText: String?) async {
        guard isEnabled else {
            return
        }

        let runID = beginNewRun()
        let promptEndingPolicy = promptEndingPolicy()
        promptSpeechStarted = false
        appState.lastError = nil
        setState(.voiceModePromptListening, detail: "\(command.displayName). Listening for your request.")
        await playConfirmationCue(command)
        startNoSpeechTimeout(runID: runID, command: command)

        do {
            try await capture.start(
                configuration: VoiceGateCaptureConfiguration(
                    silenceTimeout: promptEndingPolicy.captureSilenceTimeout,
                    sensitivity: .medium
                ),
                onSpeechStarted: { [weak self] startedAt in
                    guard let self, self.isCurrentRun(runID) else {
                        return
                    }

                    self.promptSpeechStarted = true
                    self.cancelNoSpeechTimeout()
                    self.setState(.voiceModePromptRecording(startedAt: startedAt), detail: "Listening for the end of your request.")
                },
                onUtteranceEnded: { [weak self] recordedAudio in
                    self?.activeOperationTask = Task { @MainActor [weak self] in
                        await self?.handlePromptUtterance(
                            recordedAudio,
                            runID: runID,
                            command: command,
                            selectedText: selectedText,
                            promptEndingPolicy: promptEndingPolicy
                        )
                    }
                },
                onError: { [weak self] error in
                    guard let self, self.isCurrentRun(runID) else {
                        return
                    }

                    self.fail(error)
                }
            )
        } catch let error as AppError {
            guard isCurrentRun(runID) else {
                return
            }
            fail(error)
        } catch {
            guard isCurrentRun(runID) else {
                return
            }
            fail(.recordingFailed(details: error.localizedDescription))
        }
    }

    private func handlePromptUtterance(
        _ recordedAudio: RecordedAudio,
        runID: Int,
        command: VoiceModeActivationCommand,
        selectedText: String?,
        promptEndingPolicy: VoiceModePromptEndingPolicy
    ) async {
        guard isEnabled, isCurrentRun(runID) else {
            deleteTemporaryAudio(recordedAudio)
            return
        }

        cancelNoSpeechTimeout()

        do {
            guard try await verifyRequestSpeaker(recordedAudio) else {
                deleteTemporaryAudio(recordedAudio)
                guard isEnabled, isCurrentRun(runID) else {
                    return
                }

                await startWakeListening(detail: "Different voice ignored. Listening again.")
                return
            }

            guard isEnabled, isCurrentRun(runID) else {
                deleteTemporaryAudio(recordedAudio)
                return
            }

            let transcript = try await pipeline.transcribeForVoiceMode(
                recordedAudio,
                status: "Transcribing request..."
            )
            let promptText = promptEndingPolicy.promptText(from: transcript.text)
            let composedText = VoiceModePromptComposer.compose(
                userPrompt: promptText.text,
                selectedText: selectedText
            )
            guard isEnabled, isCurrentRun(runID) else {
                return
            }

            guard !composedText.isEmpty else {
                setState(.cancelled, detail: "No request was detected.")
                await startWakeListening()
                return
            }

            let reviewedPrompt = await promptPreview(
                command,
                composedText,
                selectedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            )

            guard !Task.isCancelled, isEnabled, isCurrentRun(runID) else {
                return
            }

            guard let reviewedText = reviewedPrompt else {
                setState(.cancelled, detail: "Prompt cancelled.")
                await startWakeListening()
                return
            }

            let userText = reviewedText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !userText.isEmpty else {
                setState(.cancelled, detail: "Prompt cancelled.")
                await startWakeListening()
                return
            }

            setState(.voiceModeThinking, detail: "Generating response...")
            if let validationError = responseBackendValidationError() {
                throw validationError
            }

            let result = try await onAssistantSessionRequest(command, userText)
            let delivery = result.delivery
            let response = result.responseText.trimmingCharacters(in: .whitespacesAndNewlines)

            guard isEnabled, isCurrentRun(runID) else {
                return
            }

            guard !response.isEmpty else {
                throw AppError.voiceModeResponseFailed(details: "The response provider returned an empty Assistant response.")
            }

            switch delivery {
            case .spoken:
                setState(.voiceModeSpeaking, detail: "Preparing spoken response...")
                try await speechOutput.speak(
                    response,
                    voiceIdentifier: speechVoiceIdentifier(),
                    speed: speechSpeed(),
                    onStatusChanged: { [weak self] detail in
                        guard let self, self.isEnabled, self.isCurrentRun(runID) else {
                            return
                        }
                        self.setState(.voiceModeSpeaking, detail: detail)
                    }
                )
            case .textResponse:
                break
            }

            guard isEnabled, isCurrentRun(runID) else {
                return
            }

            setState(.completed(Transcript(text: response, segments: [])), detail: "Assistant response completed.")
            await startWakeListening()
        } catch let error as AppError {
            guard isCurrentRun(runID) else {
                return
            }
            fail(error)
        } catch {
            guard isCurrentRun(runID) else {
                return
            }
            fail(.unknown(details: error.localizedDescription))
        }
    }

    private func startNoSpeechTimeout(runID: Int, command: VoiceModeActivationCommand) {
        cancelNoSpeechTimeout()
        let timeout = max(1, noSpeechTimeoutSeconds())
        let milliseconds = Int(timeout * 1000)

        noSpeechTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(milliseconds))
            guard !Task.isCancelled else {
                return
            }

            await self?.cancelPromptForNoSpeech(runID: runID, command: command)
        }
    }

    private func cancelPromptForNoSpeech(runID: Int, command: VoiceModeActivationCommand) async {
        guard isEnabled, isCurrentRun(runID), !promptSpeechStarted else {
            return
        }

        capture.stop()
        setState(.cancelled, detail: "Assistant cancelled because no request followed \(command.displayName).")
        await startWakeListening()
    }

    private func cancelNoSpeechTimeout() {
        noSpeechTimeoutTask?.cancel()
        noSpeechTimeoutTask = nil
    }

    private func cancelActiveOperation() {
        activeOperationTask?.cancel()
        activeOperationTask = nil
    }

    private func prewarmSpeechOutputIfNeeded() {
        guard speechPrewarmTask == nil else {
            return
        }

        speechPrewarmTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await self.speechOutput.prepare(
                    voiceIdentifier: self.speechVoiceIdentifier(),
                    onStatusChanged: { detail in
                        DiagnosticLog.write("Kokoro prewarm status: \(detail)")
                    }
                )
            } catch is CancellationError {
                DiagnosticLog.write("Kokoro prewarm cancelled")
            } catch {
                DiagnosticLog.write("Kokoro prewarm failed: \(error.localizedDescription)")
            }

            if !Task.isCancelled {
                self.speechPrewarmTask = nil
            }
        }
    }

    private func cancelSpeechPrewarm() {
        speechPrewarmTask?.cancel()
        speechPrewarmTask = nil
    }

    private func selectedTextContext(for command: VoiceModeActivationCommand) async -> String? {
        guard command != .cleanUpSelection else {
            return nil
        }

        return await selectedTextProvider()
    }

    private func cleanUpSelection() async {
        setState(.cleaning, detail: "Cleaning selected text with Prime...")
        guard await onCleanUpSelection() else {
            let failureDetail = appState.lastError?.userMessage
                ?? appState.lastDetail
                ?? "Computer cleanup failed."
            await startWakeListening(detail: "\(failureDetail) Listening again.")
            return
        }

        guard isEnabled else {
            return
        }

        await startWakeListening()
    }

    private func fail(_ error: AppError) {
        isEnabled = false
        invalidateCurrentRun()
        cancelNoSpeechTimeout()
        capture.stop()
        speechOutput.stop()
        appState.lastError = error
        setState(.failed(error))
        onStopped()
    }

    private func deleteTemporaryAudio(_ recordedAudio: RecordedAudio) {
        try? FileManager.default.removeItem(at: recordedAudio.fileURL)
    }

    private func beginNewRun() -> Int {
        runID += 1
        return runID
    }

    private func invalidateCurrentRun() {
        runID += 1
    }

    private func isCurrentRun(_ runID: Int) -> Bool {
        self.runID == runID
    }

    private func setState(_ state: DictationState, detail: String? = nil) {
        appState.state = state
        if let detail {
            appState.lastDetail = detail
        }
        onStateChanged()
    }
}
