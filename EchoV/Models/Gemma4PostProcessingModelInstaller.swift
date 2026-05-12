import Foundation

struct Gemma4PostProcessingModelInstaller: Sendable {
    private let maxAttempts = 3

    func install(
        proxySettings: ProxySettings = .disabled,
        progress: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        let destination = Gemma4PostProcessingModelLayout.managedModelURL
        let fileURL = destination.appendingPathComponent(Gemma4PostProcessingModelLayout.ggufFileName)
        let partialURL = destination.appendingPathComponent("\(Gemma4PostProcessingModelLayout.ggufFileName).download")

        DiagnosticLog.write("Managed Gemma install started destination=\(destination.path)")

        var lastError: Error?

        for attempt in 1...maxAttempts {
            let isCleanRetry = attempt == maxAttempts
            let attemptLabel = "attempt \(attempt)/\(maxAttempts)"

            if attempt > 1 {
                let retryMessage = isCleanRetry
                    ? "Retrying Gemma download with a clean file..."
                    : "Retrying Gemma download..."
                progress(retryMessage)
                DiagnosticLog.write("Managed Gemma install retry \(attemptLabel) clean=\(isCleanRetry)")
            }

            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

                if isCleanRetry || FileManager.default.fileExists(atPath: partialURL.path) {
                    try? FileManager.default.removeItem(at: partialURL)
                }

                try await downloadModel(to: partialURL, proxySettings: proxySettings) { detail in
                    progress(attempt == 1 ? detail : "\(detail) (\(attemptLabel))")
                }

                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }

                try FileManager.default.moveItem(at: partialURL, to: fileURL)
                try validateInstalledModel(at: destination)
                DiagnosticLog.write("Managed Gemma install completed destination=\(destination.path)")
                return destination
            } catch {
                lastError = error
                DiagnosticLog.write(
                    "Managed Gemma install failed \(attemptLabel) clean=\(isCleanRetry) error=\(error.localizedDescription)"
                )

                if attempt < maxAttempts {
                    try await Task.sleep(for: .seconds(2))
                }
            }
        }

        throw GemmaInstallError.retryLimitReached(
            attempts: maxAttempts,
            underlying: lastError?.localizedDescription ?? "Unknown error"
        )
    }

    private func downloadModel(
        to partialURL: URL,
        proxySettings: ProxySettings,
        progress: @escaping @Sendable (String) -> Void
    ) async throws {
        progress("Starting Gemma 4 E2B Q4 download...")

        var request = URLRequest(url: Gemma4PostProcessingModelLayout.downloadURL)
        request.setValue("EchoV", forHTTPHeaderField: "User-Agent")

        let session = ProxyURLSessionFactory(proxySettings: proxySettings).makeSession()
        defer {
            session.finishTasksAndInvalidate()
        }

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw GemmaInstallError.downloadFailed(statusCode: (response as? HTTPURLResponse)?.statusCode)
        }

        let expectedBytes = httpResponse.expectedContentLength
        FileManager.default.createFile(atPath: partialURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: partialURL)
        defer {
            try? handle.close()
        }

        var downloadedBytes: Int64 = 0
        var lastProgressUpdate = Date.distantPast
        var buffer = Data()
        buffer.reserveCapacity(1024 * 1024)

        for try await byte in bytes {
            buffer.append(byte)
            downloadedBytes += 1

            if buffer.count >= 1024 * 1024 {
                try handle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }

            if Date().timeIntervalSince(lastProgressUpdate) >= 0.75 {
                progress(Self.progressMessage(downloadedBytes: downloadedBytes, expectedBytes: expectedBytes))
                lastProgressUpdate = Date()
            }
        }

        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }

        progress("Finishing Gemma install...")
    }

    private func validateInstalledModel(at url: URL) throws {
        guard Gemma4PostProcessingModelLayout.modelFolderCandidate(for: url) != nil else {
            throw GemmaInstallError.incompleteInstall
        }
    }

    private static func progressMessage(downloadedBytes: Int64, expectedBytes: Int64) -> String {
        guard expectedBytes > 0 else {
            return "Downloading Gemma \(byteCount(downloadedBytes))"
        }

        let percent = Double(downloadedBytes) / Double(expectedBytes)
        return "Downloading Gemma \(Int(percent * 100))% (\(byteCount(downloadedBytes)) / \(byteCount(expectedBytes)))"
    }

    private static func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private enum GemmaInstallError: LocalizedError {
    case downloadFailed(statusCode: Int?)
    case incompleteInstall
    case retryLimitReached(attempts: Int, underlying: String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let statusCode):
            if let statusCode {
                return "Gemma download failed with HTTP \(statusCode)."
            }
            return "Gemma download failed."
        case .incompleteInstall:
            return "Downloaded Gemma model is incomplete."
        case .retryLimitReached(let attempts, let underlying):
            return "Gemma download failed after \(attempts) attempts. Last error: \(underlying)"
        }
    }
}
