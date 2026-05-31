import AudioToolbox
import AVFoundation
import Foundation

struct LiveSubtitleAudioCaptureConfiguration: Sendable {
    let selectedAudioDeviceID: String?
    let chunking: LiveSubtitleChunkConfiguration
}

struct LiveSubtitleAudioChunk: Identifiable, Sendable {
    let id: UUID
    let sequence: Int
    let fileURL: URL
    let startedAt: Date
    let endedAt: Date

    init(
        id: UUID = UUID(),
        sequence: Int,
        fileURL: URL,
        startedAt: Date,
        endedAt: Date
    ) {
        self.id = id
        self.sequence = sequence
        self.fileURL = fileURL
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var duration: TimeInterval {
        endedAt.timeIntervalSince(startedAt)
    }
}

@MainActor
final class LiveSubtitleAudioCapture {
    private let microphonePermission: MicrophonePermissionService

    private var engine: AVAudioEngine?
    private var session: LiveSubtitleCaptureSession?

    init(microphonePermission: MicrophonePermissionService) {
        self.microphonePermission = microphonePermission
    }

    func start(
        configuration: LiveSubtitleAudioCaptureConfiguration,
        onChunkReady: @escaping @MainActor (LiveSubtitleAudioChunk) -> Void,
        onError: @escaping @MainActor (AppError) -> Void
    ) async throws {
        guard engine == nil else {
            return
        }

        try await ensureMicrophoneAccess()

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        if let deviceID = configuration.selectedAudioDeviceID, !deviceID.isEmpty {
            try selectInputDevice(with: deviceID, for: inputNode)
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw AppError.recordingFailed(details: "No input audio format was available.")
        }

        let session = try LiveSubtitleCaptureSession(
            format: inputFormat,
            configuration: configuration.chunking,
            onChunkReady: onChunkReady,
            onError: { [weak self] error in
                self?.stop()
                onError(error)
            }
        )

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: inputFormat
        ) { buffer, _ in
            session.process(buffer, receivedAt: Date())
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            session.cancel(deleteCandidate: true)
            throw AppError.recordingFailed(details: error.localizedDescription)
        }

        self.engine = engine
        self.session = session
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        session?.cancel(deleteCandidate: true)
        engine = nil
        session = nil
    }

    private func selectInputDevice(with uid: String, for inputNode: AVAudioInputNode) throws {
        guard let audioDeviceID = MicrophoneDeviceCatalog.audioDeviceID(for: uid) else {
            throw AppError.recordingFailed(details: "The selected live subtitle audio source is no longer available.")
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
            throw AppError.recordingFailed(details: "Could not select live subtitle audio source (Core Audio status \(status)).")
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

private final class LiveSubtitleCaptureSession: @unchecked Sendable {
    private static let speechTriggerDuration: TimeInterval = 0.14

    private let format: AVAudioFormat
    private let configuration: LiveSubtitleChunkConfiguration
    private let onChunkReady: @MainActor (LiveSubtitleAudioChunk) -> Void
    private let onError: @MainActor (AppError) -> Void

    private var audioFile: AVAudioFile?
    private var candidateURL: URL?
    private var candidateStartedAt: Date?
    private var candidateFrameCount: AVAudioFramePosition = 0
    private var sequence = 0
    private var noiseFloorDecibels: Float = -62
    private var aboveThresholdStartedAt: Date?
    private var speechStartedAt: Date?
    private var lastSpeechAt: Date?
    private var isCancelled = false
    private var recentBuffers: [BufferedAudio] = []
    private var recentBufferDuration: TimeInterval = 0

    init(
        format: AVAudioFormat,
        configuration: LiveSubtitleChunkConfiguration,
        onChunkReady: @escaping @MainActor (LiveSubtitleAudioChunk) -> Void,
        onError: @escaping @MainActor (AppError) -> Void
    ) throws {
        self.format = format
        self.configuration = configuration
        self.onChunkReady = onChunkReady
        self.onError = onError
        try resetCandidate(startedAt: Date())
    }

    func process(_ buffer: AVAudioPCMBuffer, receivedAt: Date) {
        guard !isCancelled else {
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

        appendRecentBuffer(buffer)

        if speechStartedAt == nil {
            updateListeningState(isAboveThreshold: isAboveThreshold, decibels: decibels, receivedAt: receivedAt)
        } else {
            updateRecordingState(isAboveThreshold: isAboveThreshold, receivedAt: receivedAt)
        }
    }

    func cancel(deleteCandidate: Bool) {
        isCancelled = true
        audioFile = nil
        recentBuffers.removeAll()
        recentBufferDuration = 0

        if deleteCandidate, let candidateURL {
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
    }

    private func updateRecordingState(isAboveThreshold: Bool, receivedAt: Date) {
        if let speechStartedAt,
           receivedAt.timeIntervalSince(speechStartedAt) >= configuration.maxChunkSeconds {
            finishChunk(endedAt: receivedAt, continueRecording: isAboveThreshold)
            return
        }

        if isAboveThreshold {
            lastSpeechAt = receivedAt
            return
        }

        guard let lastSpeechAt else {
            self.lastSpeechAt = receivedAt
            return
        }

        if receivedAt.timeIntervalSince(lastSpeechAt) >= configuration.silenceTimeoutSeconds {
            finishChunk(endedAt: receivedAt, continueRecording: false)
        }
    }

    private func finishChunk(endedAt: Date, continueRecording: Bool) {
        guard
            let speechStartedAt,
            endedAt.timeIntervalSince(speechStartedAt) >= configuration.minimumSpeechSeconds
        else {
            discardCandidateAndListenAgain(startedAt: endedAt)
            return
        }

        guard let candidateURL, let candidateStartedAt else {
            fail(.recordingFailed(details: "Live subtitles did not create an audio chunk."))
            return
        }

        audioFile = nil
        let chunk = LiveSubtitleAudioChunk(
            sequence: sequence,
            fileURL: candidateURL,
            startedAt: candidateStartedAt,
            endedAt: endedAt
        )
        sequence += 1

        do {
            try resetCandidate(startedAt: endedAt)
            if continueRecording {
                try replayRecentAudio(duration: configuration.overlapSeconds, endingAt: endedAt)
                self.speechStartedAt = candidateStartedAt
                self.lastSpeechAt = endedAt
                self.aboveThresholdStartedAt = nil
            } else {
                self.aboveThresholdStartedAt = nil
                self.speechStartedAt = nil
                self.lastSpeechAt = nil
            }
        } catch {
            fail(.recordingFailed(details: error.localizedDescription))
            return
        }

        Task { @MainActor in
            self.onChunkReady(chunk)
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
        let preRollDuration = configuration.preRollSeconds
        guard preRollDuration > 0 else {
            discardCandidateAndListenAgain(startedAt: receivedAt)
            return
        }

        let duration = TimeInterval(candidateFrameCount) / format.sampleRate
        guard duration >= preRollDuration else {
            return
        }

        discardCandidateAndListenAgain(startedAt: receivedAt)
    }

    private func resetCandidate(startedAt: Date) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoV-LiveSubtitle-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
        candidateURL = url
        candidateStartedAt = startedAt
        candidateFrameCount = 0
    }

    private func write(_ buffer: AVAudioPCMBuffer) throws {
        guard let audioFile else {
            throw AppError.recordingFailed(details: "Live subtitle audio file is not open.")
        }

        try audioFile.write(from: buffer)
        candidateFrameCount += AVAudioFramePosition(buffer.frameLength)
    }

    private func replayRecentAudio(duration: TimeInterval, endingAt: Date) throws {
        guard duration > 0, !recentBuffers.isEmpty else {
            return
        }

        var selectedBuffers: [BufferedAudio] = []
        var selectedDuration: TimeInterval = 0
        for recentBuffer in recentBuffers.reversed() {
            selectedBuffers.insert(recentBuffer, at: 0)
            selectedDuration += recentBuffer.duration
            if selectedDuration >= duration {
                break
            }
        }

        candidateStartedAt = endingAt.addingTimeInterval(-selectedDuration)
        for selectedBuffer in selectedBuffers {
            try write(selectedBuffer.buffer)
        }
    }

    private func appendRecentBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let copiedBuffer = Self.copy(buffer) else {
            return
        }

        let duration = TimeInterval(buffer.frameLength) / buffer.format.sampleRate
        recentBuffers.append(BufferedAudio(buffer: copiedBuffer, duration: duration))
        recentBufferDuration += duration

        let maximumDuration = max(configuration.preRollSeconds, configuration.overlapSeconds) + 0.25
        while recentBufferDuration > maximumDuration, !recentBuffers.isEmpty {
            let removed = recentBuffers.removeFirst()
            recentBufferDuration -= removed.duration
        }
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
        cancel(deleteCandidate: true)
        Task { @MainActor in
            self.onError(error)
        }
    }

    private static func copy(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copied = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            return nil
        }

        copied.frameLength = buffer.frameLength
        guard let sourceChannels = buffer.floatChannelData,
              let destinationChannels = copied.floatChannelData else {
            return nil
        }

        let channelCount = Int(buffer.format.channelCount)
        let byteCount = Int(buffer.frameLength) * MemoryLayout<Float>.size
        for channel in 0..<channelCount {
            memcpy(destinationChannels[channel], sourceChannels[channel], byteCount)
        }

        return copied
    }
}

private struct BufferedAudio {
    let buffer: AVAudioPCMBuffer
    let duration: TimeInterval
}
