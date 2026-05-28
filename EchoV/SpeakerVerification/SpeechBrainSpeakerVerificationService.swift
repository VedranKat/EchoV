import Foundation

actor SpeechBrainSpeakerVerificationService: SpeakerVerificationService {
    private let modelID = "speechbrain/spkrec-ecapa-voxceleb"
    private let processRunner: SpeakerVerifierProcessRunning

    init(processRunner: SpeakerVerifierProcessRunning = SpeakerVerifierProcessRunner()) {
        self.processRunner = processRunner
    }

    func enroll(audioURL: URL) async throws -> SpeakerProfile {
        let response: EnrollmentResponse = try await processRunner.run(
            arguments: ["enroll", "--audio", audioURL.path]
        )

        guard !response.embedding.isEmpty else {
            throw AppError.speakerVerificationFailed(details: "SpeechBrain returned an empty voice profile.")
        }

        return SpeakerProfile(
            modelID: response.modelID.isEmpty ? modelID : response.modelID,
            embedding: response.embedding
        )
    }

    func score(audioURL: URL, profile: SpeakerProfile, threshold: Double) async throws -> SpeakerMatchResult {
        let profileData = try JSONEncoder.speakerProfileEncoder.encode(profile)
        let profileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EchoV-SpeakerProfile-\(UUID().uuidString)")
            .appendingPathExtension("json")
        try profileData.write(to: profileURL, options: .atomic)
        defer {
            try? FileManager.default.removeItem(at: profileURL)
        }

        let response: ScoreResponse = try await processRunner.run(
            arguments: [
                "score",
                "--audio", audioURL.path,
                "--profile", profileURL.path
            ]
        )

        return SpeakerMatchResult(similarity: response.similarity, threshold: threshold)
    }
}

protocol SpeakerVerifierProcessRunning: Sendable {
    func run<Response: Decodable & Sendable>(arguments: [String]) async throws -> Response
}

struct SpeakerVerifierProcessRunner: SpeakerVerifierProcessRunning {
    func run<Response: Decodable & Sendable>(arguments: [String]) async throws -> Response {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = try Self.resolvePythonExecutable()
            process.arguments = [try Self.resolveScriptURL().path] + arguments

            var environment = ProcessInfo.processInfo.environment
            environment["PYTHONUNBUFFERED"] = "1"
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
                return try JSONDecoder.speakerProfileDecoder.decode(Response.self, from: outputData)
            } catch {
                let output = String(data: outputData, encoding: .utf8) ?? ""
                throw AppError.speakerVerificationFailed(
                    details: "Could not read speaker verifier response: \(error.localizedDescription)\n\(output)"
                )
            }
        }.value
    }

    private static func resolvePythonExecutable() throws -> URL {
        let fileManager = FileManager.default
        let candidateURLs = [
            ProcessInfo.processInfo.environment["ECHOV_SPEAKER_VERIFIER_PYTHON"].map(URL.init(fileURLWithPath:)),
            Self.managedVirtualEnvironmentPythonURL(),
            Self.projectVirtualEnvironmentPythonURL(),
            Self.bundleRelativeProjectVirtualEnvironmentPythonURL(),
            URL(fileURLWithPath: "/opt/homebrew/bin/python3"),
            URL(fileURLWithPath: "/usr/local/bin/python3"),
            URL(fileURLWithPath: "/usr/bin/python3")
        ]
        .compactMap { $0 }

        if let executableURL = candidateURLs.first(where: { fileManager.isExecutableFile(atPath: $0.path) }) {
            DiagnosticLog.write("Speaker verifier using python=\(executableURL.path)")
            return executableURL
        }

        throw AppError.speakerVerificationFailed(details: "Python 3 was not found. Install Python and SpeechBrain to use Voice Guard.")
    }

    private static func managedVirtualEnvironmentPythonURL() -> URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EchoV/Runtimes/speaker-verifier", isDirectory: true)
            .appendingPathComponent("bin/python3")
    }

    private static func projectVirtualEnvironmentPythonURL() -> URL? {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Tools/SpeakerVerifier/.venv/bin/python3")
    }

    private static func bundleRelativeProjectVirtualEnvironmentPythonURL() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else {
            return nil
        }

        return bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tools/SpeakerVerifier/.venv/bin/python3")
    }

    private static func resolveScriptURL() throws -> URL {
        let fileManager = FileManager.default
        let candidates = [
            Bundle.main.resourceURL?
                .appendingPathComponent("SpeakerVerifier", isDirectory: true)
                .appendingPathComponent("speaker_verifier.py"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Tools/SpeakerVerifier/speaker_verifier.py")
        ].compactMap { $0 }

        if let scriptURL = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) {
            return scriptURL
        }

        throw AppError.speakerVerificationFailed(details: "Speaker verifier helper was not found in EchoV resources.")
    }
}

private struct EnrollmentResponse: Decodable, Sendable {
    let modelID: String
    let embedding: [Double]

    private enum CodingKeys: String, CodingKey {
        case modelID = "model_id"
        case embedding
    }
}

private struct ScoreResponse: Decodable, Sendable {
    let similarity: Double
}

private extension JSONEncoder {
    static var speakerProfileEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var speakerProfileDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
