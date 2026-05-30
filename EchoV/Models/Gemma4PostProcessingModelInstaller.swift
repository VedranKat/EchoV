import Foundation

struct Gemma4PostProcessingModelInstaller: Sendable {
    private let maxAttempts = 3

    func install(
        modelDefinition: PostProcessingModelDefinition = .defaultModel,
        proxySettings: ProxySettings = .disabled,
        progress: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        let destination = Gemma4PostProcessingModelLayout.managedModelURL(for: modelDefinition)
        let fileURL = destination.appendingPathComponent(modelDefinition.ggufFileName)
        let partialURL = destination.appendingPathComponent("\(modelDefinition.ggufFileName).download")

        DiagnosticLog.write(
            "Managed Gemma install started model=\(modelDefinition.id) destination=\(destination.path)"
        )

        var lastError: Error?

        for attempt in 1...maxAttempts {
            let isCleanRetry = attempt == maxAttempts
            let attemptLabel = "attempt \(attempt)/\(maxAttempts)"

            if attempt > 1 {
                let retryMessage = isCleanRetry
                    ? "Retrying \(modelDefinition.displayName) download with a clean file..."
                    : "Retrying \(modelDefinition.displayName) download..."
                progress(retryMessage)
                DiagnosticLog.write(
                    "Managed Gemma install retry model=\(modelDefinition.id) \(attemptLabel) clean=\(isCleanRetry)"
                )
            }

            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

                if isCleanRetry || FileManager.default.fileExists(atPath: partialURL.path) {
                    try? FileManager.default.removeItem(at: partialURL)
                }

                try await downloadModel(
                    modelDefinition: modelDefinition,
                    to: partialURL,
                    proxySettings: proxySettings
                ) { detail in
                    progress(attempt == 1 ? detail : "\(detail) (\(attemptLabel))")
                }

                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }

                try FileManager.default.moveItem(at: partialURL, to: fileURL)
                try validateInstalledModel(at: destination, modelDefinition: modelDefinition)
                DiagnosticLog.write(
                    "Managed Gemma install completed model=\(modelDefinition.id) destination=\(destination.path)"
                )
                return destination
            } catch {
                lastError = error
                DiagnosticLog.write(
                    "Managed Gemma install failed model=\(modelDefinition.id) \(attemptLabel) clean=\(isCleanRetry) error=\(error.localizedDescription)"
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
        modelDefinition: PostProcessingModelDefinition,
        to partialURL: URL,
        proxySettings: ProxySettings,
        progress: @escaping @Sendable (String) -> Void
    ) async throws {
        progress("Starting \(modelDefinition.displayName) \(modelDefinition.quantization) download...")

        var request = URLRequest(url: modelDefinition.downloadURL)
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
                progress(
                    Self.progressMessage(
                        modelDefinition: modelDefinition,
                        downloadedBytes: downloadedBytes,
                        expectedBytes: expectedBytes
                    )
                )
                lastProgressUpdate = Date()
            }
        }

        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }

        progress("Finishing \(modelDefinition.displayName) install...")
    }

    private func validateInstalledModel(
        at url: URL,
        modelDefinition: PostProcessingModelDefinition
    ) throws {
        guard Gemma4PostProcessingModelLayout.modelFolderCandidate(
            for: url,
            definition: modelDefinition
        ) != nil else {
            throw GemmaInstallError.incompleteInstall
        }
    }

    private static func progressMessage(
        modelDefinition: PostProcessingModelDefinition,
        downloadedBytes: Int64,
        expectedBytes: Int64
    ) -> String {
        guard expectedBytes > 0 else {
            return "Downloading \(modelDefinition.displayName) \(byteCount(downloadedBytes))"
        }

        let percent = Double(downloadedBytes) / Double(expectedBytes)
        return "Downloading \(modelDefinition.displayName) \(Int(percent * 100))% (\(byteCount(downloadedBytes)) / \(byteCount(expectedBytes)))"
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
