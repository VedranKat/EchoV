import AudioToolbox
import AVFoundation
import Foundation

struct VoiceGateCaptureConfiguration {
    let silenceTimeout: VoiceGateSilenceTimeout
    let sensitivity: VoiceGateSensitivity
}

@MainActor
final class VoiceActivatedAudioCapture {
    private let microphonePermission: MicrophonePermissionService
    private let selectedMicrophoneDeviceID: @MainActor @Sendable () -> String?

    private var engine: AVAudioEngine?
    private var session: VoiceGateCaptureSession?

    init(
        microphonePermission: MicrophonePermissionService,
        selectedMicrophoneDeviceID: @escaping @MainActor @Sendable () -> String? = { nil }
    ) {
        self.microphonePermission = microphonePermission
        self.selectedMicrophoneDeviceID = selectedMicrophoneDeviceID
    }

    func start(
        configuration: VoiceGateCaptureConfiguration,
        onSpeechStarted: @escaping @MainActor (Date) -> Void,
        onUtteranceEnded: @escaping @MainActor (RecordedAudio) -> Void,
        onError: @escaping @MainActor (AppError) -> Void
    ) async throws {
        guard engine == nil else {
            return
        }

        try await ensureMicrophoneAccess()

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        if let deviceID = selectedMicrophoneDeviceID(), !deviceID.isEmpty {
            try selectInputDevice(with: deviceID, for: inputNode)
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw AppError.recordingFailed(details: "No input audio format was available.")
        }

        let session = try VoiceGateCaptureSession(
            format: inputFormat,
            configuration: configuration,
            onSpeechStarted: onSpeechStarted,
            onUtteranceEnded: { [weak self] recordedAudio in
                self?.stopEngine(cancelSession: false)
                onUtteranceEnded(recordedAudio)
            },
            onError: { [weak self] error in
                self?.stop()
                onError(error)
            }
        )

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: inputFormat,
            block: makeVoiceGateTapHandler(session: session)
        )

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            session.cancel()
            throw AppError.recordingFailed(details: error.localizedDescription)
        }

        self.engine = engine
        self.session = session
    }

    func stop() {
        stopEngine(cancelSession: true)
    }

    private func stopEngine(cancelSession: Bool) {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()

        if cancelSession {
            session?.cancel()
        }

        engine = nil
        session = nil
    }

    private func selectInputDevice(with uid: String, for inputNode: AVAudioInputNode) throws {
        guard let audioDeviceID = MicrophoneDeviceCatalog.audioDeviceID(for: uid) else {
            throw AppError.recordingFailed(details: "The selected microphone is no longer available.")
        }

        guard let audioUnit = inputNode.audioUnit else {
            throw AppError.recordingFailed(details: "The audio input unit was not available.")
        }

        var mutableDeviceID = audioDeviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        guard status == noErr else {
            throw AppError.recordingFailed(details: "Could not select microphone device (Core Audio status \(status)).")
        }
    }

    private func ensureMicrophoneAccess() async throws {
        switch microphonePermission.authorizationStatus() {
        case .authorized:
            return
        case .notDetermined:
            let granted = await microphonePermission.requestAccess()
            if granted {
                return
            }
            throw AppError.microphonePermissionDenied
        case .denied, .restricted:
            throw AppError.microphonePermissionDenied
        @unknown default:
            throw AppError.microphonePermissionDenied
        }
    }
}

private func makeVoiceGateTapHandler(session: VoiceGateCaptureSession) -> AVAudioNodeTapBlock {
    { buffer, _ in
        session.process(buffer, receivedAt: Date())
    }
}

private final class VoiceGateCaptureSession: @unchecked Sendable {
    private static let speechTriggerDuration: TimeInterval = 0.16
    private static let minimumSpeechDuration: TimeInterval = 0.35
    private static let preRollDuration: TimeInterval = 0.5

    private let format: AVAudioFormat
    private let configuration: VoiceGateCaptureConfiguration
    private let onSpeechStarted: @MainActor (Date) -> Void
    private let onUtteranceEnded: @MainActor (RecordedAudio) -> Void
    private let onError: @MainActor (AppError) -> Void

    private var audioFile: AVAudioFile?
    private var candidateURL: URL?
    private var candidateStartedAt: Date?
    private var candidateFrameCount: AVAudioFramePosition = 0
    private var noiseFloorDecibels: Float = -62
    private var aboveThresholdStartedAt: Date?
    private var speechStartedAt: Date?
    private var lastSpeechAt: Date?
    private var hasCompletedUtterance = false
    private var isCancelled = false

    init(
        format: AVAudioFormat,
        configuration: VoiceGateCaptureConfiguration,
        onSpeechStarted: @escaping @MainActor (Date) -> Void,
        onUtteranceEnded: @escaping @MainActor (RecordedAudio) -> Void,
        onError: @escaping @MainActor (AppError) -> Void
    ) throws {
        self.format = format
        self.configuration = configuration
        self.onSpeechStarted = onSpeechStarted
        self.onUtteranceEnded = onUtteranceEnded
        self.onError = onError
        try resetCandidate(startedAt: Date())
    }

    func process(_ buffer: AVAudioPCMBuffer, receivedAt: Date) {
        guard !isCancelled, !hasCompletedUtterance else {
            return
        }

        let decibels = rmsDecibels(for: buffer)
        let threshold = max(
            configuration.sensitivity.minimumSpeechDecibels,
            noiseFloorDecibels + configuration.sensitivity.noiseFloorOffsetDecibels
        )
        let isAboveThreshold = decibels >= threshold

        if speechStartedAt == nil, aboveThresholdStartedAt == nil, !isAboveThreshold {
            rotateCandidateIfNeeded(at: receivedAt)
        }

        do {
            try write(buffer)
        } catch {
            fail(.recordingFailed(details: error.localizedDescription))
            return
        }

        if speechStartedAt == nil {
            updateListeningState(isAboveThreshold: isAboveThreshold, decibels: decibels, receivedAt: receivedAt)
        } else {
            updateRecordingState(isAboveThreshold: isAboveThreshold, receivedAt: receivedAt)
        }
    }

    func cancel() {
        isCancelled = true
        audioFile = nil

        if let candidateURL {
            try? FileManager.default.removeItem(at: candidateURL)
        }

        candidateURL = nil
    }

    private func updateListeningState(isAboveThreshold: Bool, decibels: Float, receivedAt: Date) {
        guard isAboveThreshold else {
            aboveThresholdStartedAt = nil
            updateNoiseFloor(with: decibels)
            return
        }

        if aboveThresholdStartedAt == nil {
            aboveThresholdStartedAt = receivedAt
        }

        guard
            let aboveThresholdStartedAt,
            receivedAt.timeIntervalSince(aboveThresholdStartedAt) >= Self.speechTriggerDuration
        else {
            return
        }

        speechStartedAt = aboveThresholdStartedAt
        lastSpeechAt = receivedAt
        Task { @MainActor in
            self.onSpeechStarted(aboveThresholdStartedAt)
        }
    }

    private func updateRecordingState(isAboveThreshold: Bool, receivedAt: Date) {
        if isAboveThreshold {
            lastSpeechAt = receivedAt
            return
        }

        guard let lastSpeechAt else {
            self.lastSpeechAt = receivedAt
            return
        }

        if receivedAt.timeIntervalSince(lastSpeechAt) >= configuration.silenceTimeout.seconds {
            finishUtterance(endedAt: receivedAt)
        }
    }

    private func finishUtterance(endedAt: Date) {
        guard
            let speechStartedAt,
            endedAt.timeIntervalSince(speechStartedAt) >= Self.minimumSpeechDuration
        else {
            discardCandidateAndListenAgain(startedAt: endedAt)
            return
        }

        guard let candidateURL, let candidateStartedAt else {
            fail(.recordingFailed(details: "Voice Gate did not create an audio file."))
            return
        }

        hasCompletedUtterance = true
        audioFile = nil

        let recordedAudio = RecordedAudio(
            fileURL: candidateURL,
            startedAt: candidateStartedAt,
            endedAt: endedAt
        )

        Task { @MainActor in
            self.onUtteranceEnded(recordedAudio)
        }
    }

    private func discardCandidateAndListenAgain(startedAt: Date) {
        audioFile = nil

        if let candidateURL {
            try? FileManager.default.removeItem(at: candidateURL)
        }

        candidateURL = nil
        candidateStartedAt = nil
        candidateFrameCount = 0
        aboveThresholdStartedAt = nil
        speechStartedAt = nil
        lastSpeechAt = nil

        do {
            try resetCandidate(startedAt: startedAt)
        } catch {
            fail(.recordingFailed(details: error.localizedDescription))
        }
    }

    private func rotateCandidateIfNeeded(at receivedAt: Date) {
        let duration = TimeInterval(candidateFrameCount) / format.sampleRate
        guard duration >= Self.preRollDuration else {
            return
        }

        discardCandidateAndListenAgain(startedAt: receivedAt)
    }

    private func resetCandidate(startedAt: Date) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoV-VoiceGate-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        candidateURL = url
        candidateStartedAt = startedAt
        candidateFrameCount = 0
    }

    private func write(_ buffer: AVAudioPCMBuffer) throws {
        guard let audioFile else {
            throw AppError.recordingFailed(details: "Voice Gate audio file is not open.")
        }

        try audioFile.write(from: buffer)
        candidateFrameCount += AVAudioFramePosition(buffer.frameLength)
    }

    private func updateNoiseFloor(with decibels: Float) {
        let clamped = max(-90, min(decibels, -20))
        noiseFloorDecibels = (noiseFloorDecibels * 0.96) + (clamped * 0.04)
    }

    private func rmsDecibels(for buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return -120
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else {
            return -120
        }

        var sum: Float = 0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = samples[frame]
                sum += sample * sample
            }
        }

        let meanSquare = sum / Float(channelCount * frameLength)
        let rms = sqrt(max(meanSquare, 0.000_000_000_001))
        return 20 * log10(rms)
    }

    private func fail(_ error: AppError) {
        isCancelled = true
        cancel()
        Task { @MainActor in
            self.onError(error)
        }
    }
}
