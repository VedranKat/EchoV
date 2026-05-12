import Foundation

actor LlamaServerTextGenerationEngine: LocalTextGenerationEngine {
    let id = "llama-server"
    let displayName = "llama.cpp Server"

    private let modelURL: URL
    private let runtimeURL: URL?
    private let port: Int
    private let session: URLSession
    private var process: Process?

    init(modelURL: URL, runtimeURL: URL?, port: Int = 18080) {
        self.modelURL = modelURL
        self.runtimeURL = runtimeURL
        self.port = port
        self.session = Self.makeDirectLocalSession()
    }

    deinit {
        process?.terminate()
        session.invalidateAndCancel()
    }

    func prepare() async throws {
        if let process, process.isRunning {
            return
        }

        let executableURL = try Self.resolveLlamaServerExecutable(runtimeURL: runtimeURL)
        let didStartAccessingRuntime = runtimeURL?.startAccessingSecurityScopedResource() ?? false
        defer {
            if didStartAccessingRuntime {
                runtimeURL?.stopAccessingSecurityScopedResource()
            }
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [
            "--model", modelURL.path,
            "--ctx-size", "4096",
            "--n-gpu-layers", "999",
            "--host", "127.0.0.1",
            "--port", "\(port)"
        ]

        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.environment = Self.environment(for: executableURL)

        do {
            try process.run()
            self.process = process
        } catch {
            throw AppError.cleanupFailed(details: "Could not start llama-server: \(error.localizedDescription)")
        }

        do {
            try await waitUntilReady()
        } catch {
            await shutdown()
            throw error
        }
    }

    func generate(prompt: PrimeCleanupPrompt) async throws -> String {
        try await prepare()

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatCompletionRequest(
            messages: [
                .init(role: "system", content: prompt.system),
                .init(role: "user", content: prompt.user)
            ],
            temperature: 0.2,
            topP: 0.9,
            maxTokens: 512
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "No response body."
            throw AppError.cleanupFailed(details: "llama-server generation failed: \(detail)")
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw AppError.cleanupFailed(details: "llama-server returned an empty response.")
        }

        return content
    }

    private var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)")!
    }

    func shutdown() async {
        guard let process else {
            return
        }

        self.process = nil

        guard process.isRunning else {
            return
        }

        process.terminate()

        let deadline = Date().addingTimeInterval(2)
        while process.isRunning, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }

        if process.isRunning {
            process.interrupt()
        }
    }

    private func waitUntilReady() async throws {
        let deadline = Date().addingTimeInterval(120)
        var lastError: Error?

        while Date() < deadline {
            if process?.isRunning != true {
                throw AppError.cleanupFailed(details: "llama-server exited before it was ready.")
            }

            do {
                let (_, response) = try await session.data(from: baseURL.appendingPathComponent("health"))
                if let httpResponse = response as? HTTPURLResponse, (200..<500).contains(httpResponse.statusCode) {
                    return
                }
            } catch {
                lastError = error
            }

            try await Task.sleep(for: .milliseconds(500))
        }

        throw AppError.cleanupFailed(
            details: "Timed out waiting for llama-server to load Gemma. \(lastError?.localizedDescription ?? "")"
        )
    }

    private static func resolveLlamaServerExecutable(runtimeURL: URL?) throws -> URL {
        let fileManager = FileManager.default
        if let runtimeURL, let executableURL = LlamaRuntimeLayout.llamaServerCandidate(in: runtimeURL) {
            return executableURL
        }

        let candidateURLs = [
            LlamaRuntimeLayout.managedExecutableURL,
            Bundle.main.resourceURL?.appendingPathComponent("llama-b9060/llama-server"),
            Bundle.main.resourceURL?.appendingPathComponent("llama-server"),
            URL(fileURLWithPath: "/opt/homebrew/bin/llama-server"),
            URL(fileURLWithPath: "/usr/local/bin/llama-server")
        ].compactMap { $0 }

        if let url = candidateURLs.first(where: { fileManager.isExecutableFile(atPath: $0.path) }) {
            return url
        }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for directory in path.split(separator: ":") {
                let url = URL(fileURLWithPath: String(directory)).appendingPathComponent("llama-server")
                if fileManager.isExecutableFile(atPath: url.path) {
                    return url
                }
            }
        }

        throw AppError.cleanupFailed(
            details: "llama-server was not found. Bundle llama.cpp into EchoV or install it with Homebrew for development."
        )
    }

    private static func makeDirectLocalSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        return URLSession(configuration: configuration)
    }

    private static func environment(for executableURL: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let libraryPath = executableURL.deletingLastPathComponent().path
        if let existingLibraryPath = environment["DYLD_LIBRARY_PATH"], !existingLibraryPath.isEmpty {
            environment["DYLD_LIBRARY_PATH"] = "\(libraryPath):\(existingLibraryPath)"
        } else {
            environment["DYLD_LIBRARY_PATH"] = libraryPath
        }
        return environment
    }
}

private struct ChatCompletionRequest: Encodable {
    let messages: [Message]
    let temperature: Double
    let topP: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case messages
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
    }

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}
