import Foundation

@MainActor
final class VoiceModeController {
    private static let wakePhraseSilenceTimeout: TimeInterval = 0.6
    private static let maximumWakePhraseDuration: TimeInterval = 1.8

    private let appState: AppState
    private let capture: VoiceActivatedAudioCapture
    private let pipeline: DictationPipeline
    private let speechOutput: any SpeechOutputService
    private let responsePauseSeconds: @MainActor () -> TimeInterval
    private let noSpeechTimeoutSeconds: @MainActor () -> TimeInterval
    private let responseDelivery: @MainActor () -> VoiceModeResponseDelivery
    private let speechVoiceIdentifier: @MainActor () -> String
    private let speechSpeed: @MainActor () -> Double
    private let onTextResponse: @MainActor (_ userText: String, _ responseText: String) -> Void
    private var onStopped: @MainActor () -> Void
    private let onStateChanged: @MainActor () -> Void

    private var textGenerationEngine: any LocalTextGenerationEngine
    private var isEnabled = false
    private var promptSpeechStarted = false
    private var noSpeechTimeoutTask: Task<Void, Never>?
    private var runID = 0

    init(
        appState: AppState,
        capture: VoiceActivatedAudioCapture,
        pipeline: DictationPipeline,
        textGenerationEngine: any LocalTextGenerationEngine,
        speechOutput: any SpeechOutputService,
        responsePauseSeconds: @escaping @MainActor () -> TimeInterval,
        noSpeechTimeoutSeconds: @escaping @MainActor () -> TimeInterval,
        responseDelivery: @escaping @MainActor () -> VoiceModeResponseDelivery,
        speechVoiceIdentifier: @escaping @MainActor () -> String,
        speechSpeed: @escaping @MainActor () -> Double,
        onTextResponse: @escaping @MainActor (_ userText: String, _ responseText: String) -> Void,
        onStopped: @escaping @MainActor () -> Void,
        onStateChanged: @escaping @MainActor () -> Void
    ) {
        self.appState = appState
        self.capture = capture
        self.pipeline = pipeline
        self.textGenerationEngine = textGenerationEngine
        self.speechOutput = speechOutput
        self.responsePauseSeconds = responsePauseSeconds
        self.noSpeechTimeoutSeconds = noSpeechTimeoutSeconds
        self.responseDelivery = responseDelivery
        self.speechVoiceIdentifier = speechVoiceIdentifier
        self.speechSpeed = speechSpeed
        self.onTextResponse = onTextResponse
        self.onStopped = onStopped
        self.onStateChanged = onStateChanged
    }

    var availableSpeechVoices: [SpeechVoice] {
        speechOutput.availableVoices
    }

    func setOnStopped(_ onStopped: @escaping @MainActor () -> Void) {
        self.onStopped = onStopped
    }

    func setTextGenerationEngine(_ textGenerationEngine: any LocalTextGenerationEngine) {
        self.textGenerationEngine = textGenerationEngine
    }

    func start() async {
        isEnabled = true
        await startWakeListening()
    }

    func activateManually() async {
        isEnabled = true
        cancelNoSpeechTimeout()
        capture.stop()
        speechOutput.stop()
        await startPromptListening()
    }

    func stop() {
        let wasEnabled = isEnabled
        isEnabled = false
        invalidateCurrentRun()
        cancelNoSpeechTimeout()
        capture.stop()
        speechOutput.stop()
        if wasEnabled {
            setState(.cancelled, detail: "Voice Mode stopped.")
        }
        onStopped()
    }

    private func startWakeListening() async {
        guard isEnabled else {
            return
        }

        let runID = beginNewRun()
        cancelNoSpeechTimeout()
        appState.lastError = nil
        setState(.voiceModeWakeListening, detail: "Voice Mode is listening for Computer.")

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
                    Task { @MainActor [weak self] in
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
            deleteTemporaryAudio(recordedAudio)
            await startWakeListening()
            return
        }

        do {
            let transcript = try await pipeline.transcribeForVoiceMode(
                recordedAudio,
                status: "Checking activation phrase..."
            )

            guard isEnabled, isCurrentRun(runID) else {
                return
            }

            if WakePhraseMatcher.isActivationPhrase(transcript.text) {
                await startPromptListening()
            } else {
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

    private func startPromptListening() async {
        guard isEnabled else {
            return
        }

        let runID = beginNewRun()
        promptSpeechStarted = false
        appState.lastError = nil
        setState(.voiceModePromptListening, detail: "Computer. Listening for your request.")
        startNoSpeechTimeout(runID: runID)

        do {
            try await capture.start(
                configuration: VoiceGateCaptureConfiguration(
                    silenceTimeoutSeconds: responsePauseSeconds(),
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
                    Task { @MainActor [weak self] in
                        await self?.handlePromptUtterance(recordedAudio, runID: runID)
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

    private func handlePromptUtterance(_ recordedAudio: RecordedAudio, runID: Int) async {
        guard isEnabled, isCurrentRun(runID) else {
            deleteTemporaryAudio(recordedAudio)
            return
        }

        cancelNoSpeechTimeout()

        do {
            let transcript = try await pipeline.transcribeForVoiceMode(
                recordedAudio,
                status: "Transcribing request..."
            )
            let userText = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isEnabled, isCurrentRun(runID) else {
                return
            }

            guard !userText.isEmpty else {
                setState(.cancelled, detail: "No request was detected.")
                await startWakeListening()
                return
            }

            setState(.voiceModeThinking, detail: "Generating response...")
            let delivery = responseDelivery()
            let request: ChatGenerationRequest
            switch delivery {
            case .spoken:
                request = VoiceModePrompt(userText: userText)
                    .chatPrompt
                    .chatGenerationRequest(policy: .finalAnswerOnly)
            case .textResponse:
                request = TextResponseSessionPrompt(messages: [
                    TextResponseMessage(role: .user, text: userText)
                ]).chatGenerationRequest(policy: .finalAnswerOnly)
            }

            let generatedResponse = try await textGenerationEngine.generate(request: request)
            let response = generatedResponse.content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard isEnabled, isCurrentRun(runID) else {
                return
            }

            guard !response.isEmpty else {
                throw AppError.voiceModeResponseFailed(details: "The response provider returned an empty Voice Mode response.")
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
                onTextResponse(userText, response)
            }

            guard isEnabled, isCurrentRun(runID) else {
                return
            }

            setState(.completed(Transcript(text: response, segments: [])), detail: "Voice Mode response completed.")
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

    private func startNoSpeechTimeout(runID: Int) {
        cancelNoSpeechTimeout()
        let timeout = max(1, noSpeechTimeoutSeconds())
        let milliseconds = Int(timeout * 1000)

        noSpeechTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(milliseconds))
            guard !Task.isCancelled else {
                return
            }

            await self?.cancelPromptForNoSpeech(runID: runID)
        }
    }

    private func cancelPromptForNoSpeech(runID: Int) async {
        guard isEnabled, isCurrentRun(runID), !promptSpeechStarted else {
            return
        }

        capture.stop()
        setState(.cancelled, detail: "Voice Mode cancelled because no request followed Computer.")
        await startWakeListening()
    }

    private func cancelNoSpeechTimeout() {
        noSpeechTimeoutTask?.cancel()
        noSpeechTimeoutTask = nil
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
