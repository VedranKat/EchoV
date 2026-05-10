import Foundation
import FluidAudio

struct ParakeetModelInstaller: Sendable {
    func install(progress: @escaping @Sendable (String) -> Void) async throws -> URL {
        let destination = ParakeetLocalModelLayout.managedModelURL
        DiagnosticLog.write("Managed Parakeet install started destination=\(destination.path)")

        let installedURL = try await AsrModels.download(
            to: destination,
            version: .v3,
            progressHandler: { downloadProgress in
                progress(Self.message(for: downloadProgress))
            }
        )

        DiagnosticLog.write("Managed Parakeet install completed destination=\(installedURL.path)")
        return installedURL
    }

    private static func message(for progress: DownloadUtils.DownloadProgress) -> String {
        switch progress.phase {
        case .listing:
            return "Finding model files..."
        case .downloading(let completedFiles, let totalFiles):
            return "Downloading model \(completedFiles)/\(totalFiles)"
        case .compiling(let modelName):
            return modelName.isEmpty ? "Finishing install..." : "Preparing \(modelName)..."
        }
    }
}
