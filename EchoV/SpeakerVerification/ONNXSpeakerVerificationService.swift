import Foundation

actor ONNXSpeakerVerificationService: SpeakerVerificationService {
    private let processRunner: SpeakerVerifierNativeProcessRunning

    init(processRunner: SpeakerVerifierNativeProcessRunning = SpeakerVerifierNativeProcessRunner()) {
        self.processRunner = processRunner
    }

    func enroll(audioURL: URL) async throws -> SpeakerProfile {
        guard SpeakerVerifierRuntimeLayout.isInstalled() else {
            throw AppError.speakerVerificationFailed(details: "Install the speaker verifier before enrolling a voice profile.")
        }

        let response: ONNXEnrollmentResponse = try await processRunner.run(
            arguments: ["enroll", "--audio", audioURL.path]
        )

        guard !response.embedding.isEmpty else {
            throw AppError.speakerVerificationFailed(details: "Speaker verifier returned an empty voice profile.")
        }

        return SpeakerProfile(
            modelID: response.modelID.isEmpty ? SpeakerVerifierRuntimeLayout.modelID : response.modelID,
            embedding: response.embedding
        )
    }

    func score(audioURL: URL, profile: SpeakerProfile, threshold: Double) async throws -> SpeakerMatchResult {
        guard SpeakerVerifierRuntimeLayout.isInstalled() else {
            throw AppError.speakerVerificationFailed(details: "Install the speaker verifier before using Trusted Voice.")
        }

        guard profile.modelID == SpeakerVerifierRuntimeLayout.modelID else {
            throw AppError.speakerVerificationFailed(details: "Voice profile was created by an older verifier. Re-enroll your voice profile.")
        }

        let profileData = try JSONEncoder.onnxSpeakerProfileEncoder.encode(profile)
        let profileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoV-SpeakerProfile-\(UUID().uuidString)")
            .appendingPathExtension("json")
        try profileData.write(to: profileURL, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: profileURL)
        }

        let response: ONNXScoreResponse = try await processRunner.run(
            arguments: [
                "score",
                "--audio", audioURL.path,
                "--profile", profileURL.path
            ]
        )

        return SpeakerMatchResult(similarity: response.similarity, threshold: threshold)
    }
}

protocol SpeakerVerifierNativeProcessRunning: Sendable {
    func run<Response: Decodable & Sendable>(arguments: [String]) async throws -> Response
}

struct SpeakerVerifierNativeProcessRunner: SpeakerVerifierNativeProcessRunning {
    func run<Response: Decodable & Sendable>(arguments: [String]) async throws -> Response {
        try await Task.detached(priority: .userInitiated) {
            guard let executableURL = SpeakerVerifierRuntimeLayout.executableURL else {
                throw AppError.speakerVerificationFailed(details: "Speaker verifier executable was not found.")
            }

            let process = Process()
            process.executableURL = executableURL
            process.arguments = [
                "--model", SpeakerVerifierRuntimeLayout.modelURL.path
            ] + arguments

            var environment = ProcessInfo.processInfo.environment
            let libraryPath = SpeakerVerifierRuntimeLayout.libraryDirectoryURL.path
            if let existingPath = environment["DYLD_LIBRARY_PATH"], !existingPath.isEmpty {
                environment["DYLD_LIBRARY_PATH"] = "\(libraryPath):\(existingPath)"
            } else {
                environment["DYLD_LIBRARY_PATH"] = libraryPath
            }
            process.environment = environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                throw AppError.speakerVerificationFailed(details: "Could not start speaker verifier: \(error.localizedDescription)")
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let stderr = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let stdout = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = [stderr, stdout].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
                throw AppError.speakerVerificationFailed(
                    details: detail.isEmpty ? "Speaker verifier exited with status \(process.terminationStatus)." : detail
                )
            }

            do {
                return try JSONDecoder.onnxSpeakerProfileDecoder.decode(Response.self, from: outputData)
            } catch {
                let output = String(data: outputData, encoding: .utf8) ?? ""
                throw AppError.speakerVerificationFailed(
                    details: "Could not read speaker verifier response: \(error.localizedDescription)\n\(output)"
                )
            }
        }.value
    }
}

private struct ONNXEnrollmentResponse: Decodable, Sendable {
    let modelID: String
    let embedding: [Double]

    private enum CodingKeys: String, CodingKey {
        case modelID = "model_id"
        case embedding
    }
}

private struct ONNXScoreResponse: Decodable, Sendable {
    let similarity: Double
}

private extension JSONEncoder {
    static var onnxSpeakerProfileEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var onnxSpeakerProfileDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
