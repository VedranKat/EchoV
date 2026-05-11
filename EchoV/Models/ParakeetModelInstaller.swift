import Foundation
import FluidAudio

struct ParakeetModelInstaller: Sendable {
    private let maxAttempts = 3

    func install(progress: @escaping @Sendable (String) -> Void) async throws -> URL {
        let destination = ParakeetLocalModelLayout.managedModelURL
        DiagnosticLog.write("Managed Parakeet install started destination=\(destination.path)")

        var lastError: Error?

        for attempt in 1...maxAttempts {
            let isCleanRetry = attempt == maxAttempts
            let attemptLabel = "attempt \(attempt)/\(maxAttempts)"

            if attempt > 1 {
                let retryMessage = isCleanRetry
                    ? "Retrying model download with a clean cache..."
                    : "Resuming model download..."
                progress(retryMessage)
                DiagnosticLog.write("Managed Parakeet install retry \(attemptLabel) force=\(isCleanRetry)")
            }

            do {
                let installedURL = try await AsrModels.download(
                    to: destination,
                    force: isCleanRetry,
                    version: .v3,
                    progressHandler: { downloadProgress in
                        let message = Self.message(for: downloadProgress)
                        progress(attempt == 1 ? message : "\(message) (\(attemptLabel))")
                    }
                )

                try validateInstalledModel(at: installedURL)
                DiagnosticLog.write("Managed Parakeet install completed destination=\(installedURL.path)")
                return installedURL
            } catch {
                lastError = error
                DiagnosticLog.write(
                    "Managed Parakeet install failed \(attemptLabel) force=\(isCleanRetry) error=\(error.localizedDescription)"
                )

                if attempt < maxAttempts {
                    try await Task.sleep(for: .seconds(2))
                }
            }
        }

        throw ModelInstallError.retryLimitReached(
            attempts: maxAttempts,
            underlying: lastError?.localizedDescription ?? "Unknown error"
        )
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

    private func validateInstalledModel(at url: URL) throws {
        let missingFiles = ParakeetLocalModelLayout.missingFiles(at: url)
        guard missingFiles.isEmpty else {
            throw ModelInstallError.incompleteInstall(missingFiles: missingFiles)
        }
    }
}

private enum ModelInstallError: LocalizedError {
    case incompleteInstall(missingFiles: [String])
    case retryLimitReached(attempts: Int, underlying: String)

    var errorDescription: String? {
        switch self {
        case .incompleteInstall(let missingFiles):
            return "Downloaded model is incomplete. Missing files: \(missingFiles.joined(separator: ", "))"
        case .retryLimitReached(let attempts, let underlying):
            return "Model download failed after \(attempts) attempts. Last error: \(underlying)"
        }
    }
}
