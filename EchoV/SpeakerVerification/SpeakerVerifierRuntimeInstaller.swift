import CryptoKit
import Foundation

struct SpeakerVerifierRuntimeInstaller: Sendable {
    private let maxAttempts = 3

    func install(
        proxySettings: ProxySettings = .disabled,
        progress: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        guard let downloadBaseURL = SpeakerVerifierRuntimeLayout.downloadBaseURL,
              !SpeakerVerifierRuntimeLayout.downloadFiles.contains(where: { $0.expectedSHA256.isEmpty }) else {
            throw SpeakerVerifierRuntimeInstallError.notConfigured
        }

        guard SpeakerVerifierRuntimeLayout.isBundledSupportRuntimeAvailable() else {
            throw SpeakerVerifierRuntimeInstallError.supportRuntimeMissing
        }

        let destination = SpeakerVerifierRuntimeLayout.managedRuntimeURL
        let parentURL = destination.deletingLastPathComponent()
        let extractURL = parentURL.appendingPathComponent("\(SpeakerVerifierRuntimeLayout.version).extract", isDirectory: true)

        DiagnosticLog.write("Managed speaker verifier model install started destination=\(destination.path)")

        var lastError: Error?

        for attempt in 1...maxAttempts {
            let isCleanRetry = attempt == maxAttempts
            let attemptLabel = "attempt \(attempt)/\(maxAttempts)"

            if attempt > 1 {
                progress(isCleanRetry ? "Retrying speaker verifier model download with a clean file..." : "Retrying speaker verifier model download...")
                DiagnosticLog.write("Managed speaker verifier model install retry \(attemptLabel) clean=\(isCleanRetry)")
            }

            do {
                try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
                try? FileManager.default.removeItem(at: extractURL)
                try FileManager.default.createDirectory(at: extractURL, withIntermediateDirectories: true)

                for file in SpeakerVerifierRuntimeLayout.downloadFiles {
                    let destinationURL = Self.fileURL(in: extractURL, relativePath: file.relativePath)
                    let partialURL = destinationURL
                        .deletingLastPathComponent()
                        .appendingPathComponent("\(destinationURL.lastPathComponent).download")

                    try FileManager.default.createDirectory(
                        at: destinationURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )

                    guard let fileURL = SpeakerVerifierRuntimeLayout.downloadURL(for: file, baseURL: downloadBaseURL) else {
                        throw SpeakerVerifierRuntimeInstallError.notConfigured
                    }

                    try await downloadFile(
                        from: fileURL,
                        to: partialURL,
                        displayName: file.displayName,
                        proxySettings: proxySettings
                    ) { detail in
                        progress(attempt == 1 ? detail : "\(detail) (\(attemptLabel))")
                    }

                    try verifySHA256(of: partialURL, expectedSHA256: file.expectedSHA256, displayName: file.displayName)
                    try? FileManager.default.removeItem(at: destinationURL)
                    try FileManager.default.moveItem(at: partialURL, to: destinationURL)
                }

                guard SpeakerVerifierRuntimeLayout.isModelPackage(at: extractURL) else {
                    throw SpeakerVerifierRuntimeInstallError.incompleteInstall
                }

                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: extractURL, to: destination)

                guard SpeakerVerifierRuntimeLayout.isInstalled() else {
                    throw SpeakerVerifierRuntimeInstallError.incompleteInstall
                }

                DiagnosticLog.write("Managed speaker verifier model install completed destination=\(destination.path)")
                return destination
            } catch {
                lastError = error
                DiagnosticLog.write(
                    "Managed speaker verifier model install failed \(attemptLabel) clean=\(isCleanRetry) error=\(error.localizedDescription)"
                )

                if attempt < maxAttempts {
                    try await Task.sleep(for: .seconds(2))
                }
            }
        }

        throw SpeakerVerifierRuntimeInstallError.retryLimitReached(
            attempts: maxAttempts,
            underlying: lastError?.localizedDescription ?? "Unknown error"
        )
    }

    private func downloadFile(
        from downloadURL: URL,
        to partialURL: URL,
        displayName: String,
        proxySettings: ProxySettings,
        progress: @escaping @Sendable (String) -> Void
    ) async throws {
        if downloadURL.isFileURL {
            try copyLocalFile(from: downloadURL, to: partialURL, displayName: displayName, progress: progress)
            return
        }

        progress("Starting \(displayName) download...")

        var request = URLRequest(url: downloadURL)
        request.setValue("EchoV", forHTTPHeaderField: "User-Agent")

        let session = ProxyURLSessionFactory(proxySettings: proxySettings).makeSession()
        defer {
            session.finishTasksAndInvalidate()
        }

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw SpeakerVerifierRuntimeInstallError.downloadFailed(statusCode: (response as? HTTPURLResponse)?.statusCode)
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
                progress(Self.progressMessage(
                    displayName: displayName,
                    downloadedBytes: downloadedBytes,
                    expectedBytes: expectedBytes
                ))
                lastProgressUpdate = Date()
            }
        }

        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }

        progress("Verifying \(displayName)...")
    }

    private func copyLocalFile(
        from sourceURL: URL,
        to partialURL: URL,
        displayName: String,
        progress: @escaping @Sendable (String) -> Void
    ) throws {
        progress("Copying local \(displayName)...")

        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let expectedBytes = attributes[.size] as? Int64 ?? -1
        let input = try FileHandle(forReadingFrom: sourceURL)
        defer {
            try? input.close()
        }

        FileManager.default.createFile(atPath: partialURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: partialURL)
        defer {
            try? output.close()
        }

        var copiedBytes: Int64 = 0
        while true {
            let data = try input.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty {
                break
            }
            try output.write(contentsOf: data)
            copiedBytes += Int64(data.count)
        }

        progress(Self.progressMessage(
            displayName: displayName,
            downloadedBytes: copiedBytes,
            expectedBytes: expectedBytes
        ))
        progress("Verifying \(displayName)...")
    }

    private func verifySHA256(of url: URL, expectedSHA256: String, displayName: String) throws {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        let checksum = digest.map { String(format: "%02x", $0) }.joined()
        guard checksum == expectedSHA256 else {
            throw SpeakerVerifierRuntimeInstallError.checksumMismatch(file: displayName)
        }
    }

    private static func fileURL(in rootURL: URL, relativePath: String) -> URL {
        relativePath
            .split(separator: "/")
            .reduce(rootURL) { url, component in
                url.appendingPathComponent(String(component))
            }
    }

    private static func progressMessage(displayName: String, downloadedBytes: Int64, expectedBytes: Int64) -> String {
        guard expectedBytes > 0 else {
            return "Downloading \(displayName) \(byteCount(downloadedBytes))"
        }

        let percent = Double(downloadedBytes) / Double(expectedBytes)
        return "Downloading \(displayName) \(Int(percent * 100))% (\(byteCount(downloadedBytes)) / \(byteCount(expectedBytes)))"
    }

    private static func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private enum SpeakerVerifierRuntimeInstallError: LocalizedError {
    case notConfigured
    case downloadFailed(statusCode: Int?)
    case checksumMismatch(file: String)
    case incompleteInstall
    case supportRuntimeMissing
    case retryLimitReached(attempts: Int, underlying: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Speaker verifier model download is not configured for this build."
        case .downloadFailed(let statusCode):
            if let statusCode {
                return "Speaker verifier download failed with HTTP \(statusCode)."
            }
            return "Speaker verifier download failed."
        case .checksumMismatch(let file):
            return "Downloaded \(file) did not match the expected checksum."
        case .incompleteInstall:
            return "Downloaded speaker verifier model is incomplete."
        case .supportRuntimeMissing:
            return "This EchoV build is missing the bundled macOS speaker verifier runtime."
        case .retryLimitReached(let attempts, let underlying):
            return "Speaker verifier download failed after \(attempts) attempts. Last error: \(underlying)"
        }
    }
}
