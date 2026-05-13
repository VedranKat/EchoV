import AudioToolbox
import AVFoundation
import Foundation

protocol AudioRecorder: Sendable {
    func start() async throws -> RecordedAudio
    func stop() async throws -> RecordedAudio
}

actor AVFoundationAudioRecorder: AudioRecorder {
    private let microphonePermission: MicrophonePermissionService
    private let minimumDuration: TimeInterval
    private let selectedMicrophoneDeviceID: @MainActor @Sendable () -> String?

    private var recording: RecordedAudio?
    private var engine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var writeError: Error?

    init(
        microphonePermission: MicrophonePermissionService,
        minimumDuration: TimeInterval = 0.2,
        selectedMicrophoneDeviceID: @escaping @MainActor @Sendable () -> String? = { nil }
    ) {
        self.microphonePermission = microphonePermission
        self.minimumDuration = minimumDuration
        self.selectedMicrophoneDeviceID = selectedMicrophoneDeviceID
    }

    func start() async throws -> RecordedAudio {
        try await ensureMicrophoneAccess()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoV-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        if let deviceID = await selectedMicrophoneDeviceID(), !deviceID.isEmpty {
            try selectInputDevice(with: deviceID, for: inputNode)
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0, inputFormat.sampleRate > 0 else {
            throw AppError.recordingFailed(details: "No input audio format was available.")
        }

        let audioFile = try AVAudioFile(forWriting: url, settings: inputFormat.settings)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            do {
                try audioFile.write(from: buffer)
            } catch {
                Task {
                    await self?.rememberWriteError(error)
                }
            }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AppError.recordingFailed(details: error.localizedDescription)
        }

        let recording = RecordedAudio(fileURL: url, startedAt: Date(), endedAt: nil)
        self.engine = engine
        self.audioFile = audioFile
        self.recording = recording
        self.writeError = nil
        return recording
    }

    func stop() async throws -> RecordedAudio {
        guard let recording, let engine else {
            throw AppError.recordingFailed(details: "No active recording.")
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        let stopped = RecordedAudio(fileURL: recording.fileURL, startedAt: recording.startedAt, endedAt: Date())
        self.recording = nil
        self.engine = nil
        self.audioFile = nil

        if let writeError {
            self.writeError = nil
            throw AppError.recordingFailed(details: writeError.localizedDescription)
        }

        guard stopped.duration >= minimumDuration else {
            throw AppError.recordingTooShort
        }

        guard FileManager.default.fileExists(atPath: stopped.fileURL.path) else {
            throw AppError.recordingFailed(details: "Recorded audio file was not created.")
        }

        return stopped
    }

    private func rememberWriteError(_ error: Error) {
        writeError = error
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
