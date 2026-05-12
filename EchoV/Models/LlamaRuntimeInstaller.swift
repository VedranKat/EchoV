import CryptoKit
import Foundation

struct LlamaRuntimeInstaller: Sendable {
    private let maxAttempts = 3

    func install(progress: @escaping @Sendable (String) -> Void) async throws -> URL {
        let destination = LlamaRuntimeLayout.managedRuntimeURL
        let parentURL = destination.deletingLastPathComponent()
        let archiveURL = parentURL.appendingPathComponent(LlamaRuntimeLayout.archiveFileName)
        let partialURL = parentURL.appendingPathComponent("\(LlamaRuntimeLayout.archiveFileName).download")
        let extractURL = parentURL.appendingPathComponent("\(LlamaRuntimeLayout.version).extract", isDirectory: true)

        DiagnosticLog.write("Managed llama.cpp runtime install started destination=\(destination.path)")

        var lastError: Error?

        for attempt in 1...maxAttempts {
            let isCleanRetry = attempt == maxAttempts
            let attemptLabel = "attempt \(attempt)/\(maxAttempts)"

            if attempt > 1 {
                progress(isCleanRetry ? "Retrying runtime download with a clean file..." : "Retrying runtime download...")
                DiagnosticLog.write("Managed llama.cpp runtime install retry \(attemptLabel) clean=\(isCleanRetry)")
            }

            do {
                try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)

                if isCleanRetry || FileManager.default.fileExists(atPath: partialURL.path) {
                    try? FileManager.default.removeItem(at: partialURL)
                }
                try? FileManager.default.removeItem(at: archiveURL)
                try? FileManager.default.removeItem(at: extractURL)

                try await downloadArchive(to: partialURL) { detail in
                    progress(attempt == 1 ? detail : "\(detail) (\(attemptLabel))")
                }

                try verifySHA256(of: partialURL)
                try FileManager.default.moveItem(at: partialURL, to: archiveURL)
                try extractArchive(archiveURL, to: extractURL)

                guard let runtimeRoot = runtimeRootCandidate(in: extractURL) else {
                    throw LlamaRuntimeInstallError.incompleteInstall
                }

                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.moveItem(at: runtimeRoot, to: destination)
                try? FileManager.default.removeItem(at: archiveURL)
                try? FileManager.default.removeItem(at: extractURL)

                guard LlamaRuntimeLayout.isInstalled() else {
                    throw LlamaRuntimeInstallError.incompleteInstall
                }

                DiagnosticLog.write("Managed llama.cpp runtime install completed destination=\(destination.path)")
                return destination
            } catch {
                lastError = error
                DiagnosticLog.write(
                    "Managed llama.cpp runtime install failed \(attemptLabel) clean=\(isCleanRetry) error=\(error.localizedDescription)"
                )

                if attempt < maxAttempts {
                    try await Task.sleep(for: .seconds(2))
                }
            }
        }

        throw LlamaRuntimeInstallError.retryLimitReached(
            attempts: maxAttempts,
            underlying: lastError?.localizedDescription ?? "Unknown error"
        )
    }

    private func downloadArchive(
        to partialURL: URL,
        progress: @escaping @Sendable (String) -> Void
    ) async throws {
        progress("Starting llama.cpp runtime download...")

        var request = URLRequest(url: LlamaRuntimeLayout.downloadURL)
        request.setValue("EchoV", forHTTPHeaderField: "User-Agent")

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw LlamaRuntimeInstallError.downloadFailed(statusCode: (response as? HTTPURLResponse)?.statusCode)
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

        progress("Verifying llama.cpp runtime...")
    }

    private func verifySHA256(of url: URL) throws {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        let checksum = digest.map { String(format: "%02x", $0) }.joined()
        guard checksum == LlamaRuntimeLayout.expectedSHA256 else {
            throw LlamaRuntimeInstallError.checksumMismatch
        }
    }

    private func extractArchive(_ archiveURL: URL, to destinationURL: URL) throws {
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xzf", archiveURL.path, "-C", destinationURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw LlamaRuntimeInstallError.extractFailed
        }
    }

    private func runtimeRootCandidate(in url: URL) -> URL? {
        if LlamaRuntimeLayout.llamaServerCandidate(in: url) != nil {
            return url
        }

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return contents.first { LlamaRuntimeLayout.llamaServerCandidate(in: $0) != nil }
    }

    private static func progressMessage(downloadedBytes: Int64, expectedBytes: Int64) -> String {
        guard expectedBytes > 0 else {
            return "Downloading llama.cpp \(byteCount(downloadedBytes))"
        }

        let percent = Double(downloadedBytes) / Double(expectedBytes)
        return "Downloading llama.cpp \(Int(percent * 100))% (\(byteCount(downloadedBytes)) / \(byteCount(expectedBytes)))"
    }

    private static func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private enum LlamaRuntimeInstallError: LocalizedError {
    case downloadFailed(statusCode: Int?)
    case checksumMismatch
    case extractFailed
    case incompleteInstall
    case retryLimitReached(attempts: Int, underlying: String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let statusCode):
            if let statusCode {
                return "llama.cpp runtime download failed with HTTP \(statusCode)."
            }
            return "llama.cpp runtime download failed."
        case .checksumMismatch:
            return "Downloaded llama.cpp runtime did not match the expected checksum."
        case .extractFailed:
            return "Could not unpack the llama.cpp runtime."
        case .incompleteInstall:
            return "Downloaded llama.cpp runtime is incomplete."
        case .retryLimitReached(let attempts, let underlying):
            return "llama.cpp runtime download failed after \(attempts) attempts. Last error: \(underlying)"
        }
    }
}
