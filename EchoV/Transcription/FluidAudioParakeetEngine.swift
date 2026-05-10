import Foundation
import FluidAudio
import CoreML

actor FluidAudioParakeetEngine: ASREngine {
    nonisolated let id = "fluid-audio-parakeet"
    nonisolated let displayName = "FluidAudio Parakeet"
    nonisolated(unsafe) var onStatusUpdate: (@Sendable (String) -> Void)?

    private let modelURL: URL
    private let computeMode: ASRComputeMode
    private var asrManager: AsrManager?

    init(modelURL: URL, computeMode: ASRComputeMode) {
        self.modelURL = modelURL
        self.computeMode = computeMode
    }

    func prepare() async throws {
        _ = try await loadedManager()
    }

    func transcribe(audioURL: URL, options: ASROptions) async throws -> Transcript {
        let manager = try await loadedManager()

        do {
            let decoderLayers = await manager.decoderLayerCount
            var decoderState = TdtDecoderState.make(decoderLayers: decoderLayers)
            let result = try await manager.transcribe(audioURL, decoderState: &decoderState)
            return Transcript(
                text: result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                duration: result.duration
            )
        } catch {
            throw AppError.transcriptionFailed(details: error.localizedDescription)
        }
    }

    private func loadedManager() async throws -> AsrManager {
        if let asrManager {
            return asrManager
        }

        let didStartAccessing = modelURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                modelURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let fluidAudioModelURL = try ParakeetLocalModelLayout.localFluidAudioFolder(for: modelURL)
            let configuration = MLModelConfiguration()
            configuration.computeUnits = computeMode.computeUnits
            let models = try await AsrModels.load(
                from: fluidAudioModelURL,
                configuration: configuration,
                version: .v3,
                progressHandler: { [weak self] progress in
                    self?.publish(progress)
                }
            )
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            asrManager = manager
            return manager
        } catch {
            throw AppError.modelLoadFailed(details: error.localizedDescription)
        }
    }

    private nonisolated func publish(_ progress: DownloadUtils.DownloadProgress) {
        let percent = Int((progress.fractionCompleted * 100).rounded())
        let phase: String

        switch progress.phase {
        case .listing:
            phase = "Preparing local model"
        case .downloading(_, let totalFiles):
            if totalFiles > 0 {
                onStatusUpdate?("Unexpected remote model fetch blocked by local-only setup")
                return
            }
            phase = "Loading local model"
        case .compiling(let modelName):
            phase = "Compiling \(modelName)"
        }

        onStatusUpdate?("\(phase) (\(percent)%)")
    }
}
