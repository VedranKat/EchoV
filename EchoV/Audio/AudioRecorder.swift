import AVFoundation
import Foundation

protocol AudioRecorder: Sendable {
    func start() async throws -> RecordedAudio
    func stop() async throws -> RecordedAudio
}

actor AVFoundationAudioRecorder: AudioRecorder {
    private let microphonePermission: MicrophonePermissionService
    private let minimumDuration: TimeInterval

    private var recording: RecordedAudio?
    private var recorder: AVAudioRecorder?

    init(
        microphonePermission: MicrophonePermissionService,
        minimumDuration: TimeInterval = 0.2
    ) {
        self.microphonePermission = microphonePermission
        self.minimumDuration = minimumDuration
    }

    func start() async throws -> RecordedAudio {
        try await ensureMicrophoneAccess()

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoV-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = false

        guard recorder.prepareToRecord(), recorder.record() else {
            throw AppError.recordingFailed(details: "Could not start AVAudioRecorder.")
        }

        let recording = RecordedAudio(fileURL: url, startedAt: Date(), endedAt: nil)
        self.recorder = recorder
        self.recording = recording
        return recording
    }

    func stop() async throws -> RecordedAudio {
        guard let recording, let recorder else {
            throw AppError.recordingFailed(details: "No active recording.")
        }

        recorder.stop()

        let stopped = RecordedAudio(fileURL: recording.fileURL, startedAt: recording.startedAt, endedAt: Date())
        self.recording = nil
        self.recorder = nil

        guard stopped.duration >= minimumDuration else {
            throw AppError.recordingTooShort
        }

        guard FileManager.default.fileExists(atPath: stopped.fileURL.path) else {
            throw AppError.recordingFailed(details: "Recorded audio file was not created.")
        }

        return stopped
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
