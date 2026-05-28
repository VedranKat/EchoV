import AVFoundation
@preconcurrency import FluidAudio
import Foundation

extension KokoroTtsManager: @unchecked @retroactive Sendable {}

struct SpeechVoice: Identifiable, Equatable {
    let id: String
    let name: String
    let language: String

    var displayName: String {
        if language.isEmpty {
            return name
        }

        return "\(name) (\(language))"
    }
}

enum KokoroVoiceCatalog {
    static let defaultVoiceID = TtsConstants.recommendedVoice

    static let availableVoices: [SpeechVoice] = TtsConstants.availableVoices
        .map { voiceID in
            SpeechVoice(id: voiceID, name: displayName(for: voiceID), language: languageName(for: voiceID))
        }
        .sorted { first, second in
            first.displayName.localizedStandardCompare(second.displayName) == .orderedAscending
        }

    private static func displayName(for voiceID: String) -> String {
        voiceID
            .split(separator: "_")
            .dropFirst()
            .map { part in
                part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func languageName(for voiceID: String) -> String {
        if voiceID.hasPrefix("af_") || voiceID.hasPrefix("am_") {
            return "American English"
        }

        if voiceID.hasPrefix("bf_") || voiceID.hasPrefix("bm_") {
            return "British English"
        }

        if voiceID.hasPrefix("ef_") || voiceID.hasPrefix("em_") {
            return "Spanish"
        }

        if voiceID.hasPrefix("ff_") {
            return "French"
        }

        if voiceID.hasPrefix("hf_") || voiceID.hasPrefix("hm_") {
            return "Hindi"
        }

        if voiceID.hasPrefix("if_") || voiceID.hasPrefix("im_") {
            return "Italian"
        }

        if voiceID.hasPrefix("jf_") || voiceID.hasPrefix("jm_") {
            return "Japanese"
        }

        if voiceID.hasPrefix("pf_") || voiceID.hasPrefix("pm_") {
            return "Brazilian Portuguese"
        }

        if voiceID.hasPrefix("zf_") || voiceID.hasPrefix("zm_") {
            return "Mandarin Chinese"
        }

        return "Kokoro"
    }
}

@MainActor
protocol SpeechOutputService: AnyObject {
    var availableVoices: [SpeechVoice] { get }

    func speak(
        _ text: String,
        voiceIdentifier: String,
        speed: Double,
        onStatusChanged: @escaping @MainActor (String) -> Void
    ) async throws
    func stop()
}

@MainActor
final class KokoroSpeechOutputService: SpeechOutputService {
    private let synthesizer = KokoroSpeechSynthesizer()
    private let player = KokoroAudioPlayer()

    var availableVoices: [SpeechVoice] {
        KokoroVoiceCatalog.availableVoices
    }

    func speak(
        _ text: String,
        voiceIdentifier: String,
        speed: Double,
        onStatusChanged: @escaping @MainActor (String) -> Void
    ) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return
        }

        stop()
        onStatusChanged("Preparing Kokoro speech...")
        DiagnosticLog.write("Kokoro speech requested characters=\(trimmedText.count) voice=\(voiceIdentifier)")

        let audioData = try await synthesizer.generate(
            text: trimmedText,
            voiceIdentifier: voiceIdentifier,
            speed: Float(max(0.5, min(speed, 2.0))),
            onStatusChanged: onStatusChanged
        )

        onStatusChanged("Playing spoken response...")
        try await player.play(audioData: audioData)
        DiagnosticLog.write("Kokoro playback completed")
    }

    func stop() {
        player.stop()
    }
}

@MainActor
private final class KokoroSpeechSynthesizer {
    nonisolated(unsafe) private var manager: KokoroTtsManager?

    func generate(
        text: String,
        voiceIdentifier: String,
        speed: Float,
        onStatusChanged: @escaping @MainActor (String) -> Void
    ) async throws -> Data {
        let manager = try await configuredManager(defaultVoice: voiceIdentifier, onStatusChanged: onStatusChanged)
        onStatusChanged("Synthesizing Kokoro speech...")
        DiagnosticLog.write("Kokoro synthesis started")
        let data = try await manager.synthesize(
            text: text,
            voice: voiceIdentifier,
            voiceSpeed: speed
        )
        DiagnosticLog.write("Kokoro synthesis completed bytes=\(data.count)")
        return data
    }

    private func configuredManager(
        defaultVoice: String,
        onStatusChanged: @escaping @MainActor (String) -> Void
    ) async throws -> KokoroTtsManager {
        if let manager {
            onStatusChanged("Loading Kokoro voice...")
            try await manager.setDefaultVoice(defaultVoice)
            return manager
        }

        onStatusChanged("Loading Kokoro models...")
        DiagnosticLog.write("Kokoro manager initialization started voice=\(defaultVoice)")
        let models = try await TtsModels.download { progress in
            Task { @MainActor in
                onStatusChanged(Self.statusMessage(for: progress))
            }
        }

        onStatusChanged("Preparing Kokoro voice assets...")
        let manager = KokoroTtsManager(defaultVoice: defaultVoice)
        try await manager.initialize(models: models, preloadVoices: Set([defaultVoice]))
        self.manager = manager
        DiagnosticLog.write("Kokoro manager initialization completed")
        return manager
    }

    private static func statusMessage(for progress: DownloadUtils.DownloadProgress) -> String {
        switch progress.phase {
        case .listing:
            return "Checking Kokoro voice assets..."
        case .downloading(let completedFiles, let totalFiles):
            guard totalFiles > 0 else {
                return "Checking local Kokoro assets..."
            }
            let percent = Int((min(1.0, max(0.0, progress.fractionCompleted / 0.5)) * 100).rounded())
            return "Downloading Kokoro voice assets... \(completedFiles)/\(totalFiles) (\(percent)%)"
        case .compiling(let modelName):
            if modelName.isEmpty {
                return "Finishing Kokoro model setup..."
            }
            return "Compiling Kokoro model \(modelName)..."
        }
    }
}

@MainActor
private final class KokoroAudioPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Error>?
    private var playbackTimeoutTask: Task<Void, Never>?

    func play(audioData: Data) async throws {
        stop()

        let player = try AVAudioPlayer(data: audioData)
        player.delegate = self
        player.prepareToPlay()
        self.player = player
        DiagnosticLog.write("Kokoro playback starting duration=\(player.duration) bytes=\(audioData.count)")

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            startPlaybackTimeout(for: player.duration)
            if !player.play() {
                finish(error: AppError.speechOutputFailed(details: "AVAudioPlayer could not start Kokoro playback."))
            }
        }
    }

    func stop() {
        if player?.isPlaying == true {
            player?.stop()
        }

        player = nil
        finish()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.finish()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        Task { @MainActor [weak self] in
            self?.finish(error: AppError.speechOutputFailed(details: error?.localizedDescription ?? "Kokoro audio decode failed."))
        }
    }

    private func finish(error: (any Error)? = nil) {
        guard let continuation else {
            return
        }

        playbackTimeoutTask?.cancel()
        playbackTimeoutTask = nil
        self.continuation = nil
        player = nil

        if let error {
            DiagnosticLog.write("Kokoro playback failed: \(error.localizedDescription)")
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }

    private func startPlaybackTimeout(for duration: TimeInterval) {
        playbackTimeoutTask?.cancel()
        let timeoutSeconds = max(10.0, min(duration + 5.0, 300.0))
        let nanoseconds = UInt64(timeoutSeconds * 1_000_000_000)
        playbackTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            await MainActor.run {
                self?.finish(
                    error: AppError.speechOutputFailed(
                        details: "Kokoro playback did not finish within \(Int(timeoutSeconds)) seconds."
                    )
                )
            }
        }
    }

}
