import Foundation
import FluidAudio
import CoreML

actor FluidAudioParakeetEngine: ASREngine {
    nonisolated let id = "fluid-audio-parakeet"
    nonisolated let displayName = "FluidAudio Parakeet"
    nonisolated(unsafe) var onStatusUpdate: (@Sendable (String) -> Void)?

    private let expectedFluidAudioFolderName = "parakeet-tdt-0.6b-v3"
    private let requiredLocalFiles = [
        "Preprocessor.mlmodelc/coremldata.bin",
        "Encoder.mlmodelc/coremldata.bin",
        "Decoder.mlmodelc/coremldata.bin",
        "JointDecisionv3.mlmodelc/coremldata.bin",
        "parakeet_vocab.json"
    ]
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
            let fluidAudioModelURL = try localFluidAudioModelURL()
            try validateLocalModelFiles(at: fluidAudioModelURL)
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

    private func localFluidAudioModelURL() throws -> URL {
        if modelURL.lastPathComponent == expectedFluidAudioFolderName {
            return modelURL
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let linkDirectory = appSupport.appendingPathComponent("EchoV/ModelLinks", isDirectory: true)
        try FileManager.default.createDirectory(at: linkDirectory, withIntermediateDirectories: true)

        let linkURL = linkDirectory.appendingPathComponent(expectedFluidAudioFolderName, isDirectory: true)

        if FileManager.default.fileExists(atPath: linkURL.path) {
            try FileManager.default.removeItem(at: linkURL)
        }

        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: modelURL)
        return linkURL
    }

    private func validateLocalModelFiles(at url: URL) throws {
        let missingFiles = requiredLocalFiles.filter { relativePath in
            !FileManager.default.fileExists(atPath: url.appendingPathComponent(relativePath).path)
        }

        guard missingFiles.isEmpty else {
            throw AppError.modelPathInvalid(details: "Missing local model files: \(missingFiles.joined(separator: ", "))")
        }
    }

    private nonisolated func publish(_ progress: DownloadUtils.DownloadProgress) {
        let percent = Int((progress.fractionCompleted * 100).rounded())
        let phase: String

        switch progress.phase {
        case .listing:
            phase = "Listing model files"
        case .downloading(let completedFiles, let totalFiles):
            phase = "Loading model files \(completedFiles)/\(totalFiles)"
        case .compiling(let modelName):
            phase = "Compiling \(modelName)"
        }

        onStatusUpdate?("\(phase) (\(percent)%)")
    }
}
