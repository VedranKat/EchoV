import Foundation
import Darwin

actor LlamaServerTextGenerationEngine: LocalTextGenerationEngine {
    private static let emptyResponseRetryMaxTokens = 2048

    private enum ServerState {
        case idle
        case starting
        case ready
    }

    let id = "llama-server"
    let displayName = "llama.cpp Server"

    private let modelURL: URL
    private let runtimeURL: URL?
    private let port: Int
    private let session: URLSession
    private var process: Process?
    private var serverState: ServerState = .idle
    #if ECHOV_DEV_DIAGNOSTICS
    private var serverReadyAt: Date?
    private var serverRequestCount = 0
    #endif

    init(modelURL: URL, runtimeURL: URL?, port: Int? = nil) {
        self.modelURL = modelURL
        self.runtimeURL = runtimeURL
        self.port = port ?? Self.availableLoopbackPort()
        self.session = Self.makeDirectLocalSession()
    }

    deinit {
        process?.terminate()
        session.invalidateAndCancel()
    }

    func prepare() async throws {
        if let process {
            if process.isRunning {
                switch serverState {
                case .ready:
                    return
                case .starting:
                    try await waitUntilReady()
                    serverState = .ready
                    #if ECHOV_DEV_DIAGNOSTICS
                    if serverReadyAt == nil {
                        serverReadyAt = Date()
                    }
                    #endif
                    return
                case .idle:
                    break
                }
            } else {
                self.process = nil
                serverState = .idle
                #if ECHOV_DEV_DIAGNOSTICS
                serverReadyAt = nil
                serverRequestCount = 0
                #endif
            }
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
            serverState = .starting
            #if ECHOV_DEV_DIAGNOSTICS
            serverReadyAt = nil
            serverRequestCount = 0
            #endif
            DiagnosticLog.write(
                "llama-server started pid=\(process.processIdentifier) port=\(port) model=\(modelURL.lastPathComponent)"
            )
        } catch {
            throw AppError.cleanupFailed(details: "Could not start llama-server: \(error.localizedDescription)")
        }

        do {
            try await waitUntilReady()
            serverState = .ready
            #if ECHOV_DEV_DIAGNOSTICS
            serverReadyAt = Date()
            #endif
            DiagnosticLog.write(
                "llama-server ready pid=\(process.processIdentifier) port=\(port) model=\(modelURL.lastPathComponent)"
            )
        } catch {
            await shutdown()
            throw error
        }
    }

    func generate(prompt: LocalChatPrompt) async throws -> String {
        let request = prompt.chatGenerationRequest(policy: .finalAnswerOnly)
        return try await generateRaw(request: request)
    }

    func generate(request: ChatGenerationRequest) async throws -> ChatGenerationResult {
        let message = try await generateChatCompletionMessage(request: request)

        let parsedContent = ChatGenerationResult.fromRawOutput(message.contentText, policy: request.policy)
        switch request.policy {
        case .finalAnswerOnly:
            return parsedContent
        case .chat(_, let showReasoning):
            let reasoning = [message.reasoningText, parsedContent.reasoning]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
            return ChatGenerationResult(
                content: parsedContent.content,
                reasoning: showReasoning ? reasoning : ""
            )
        }
    }

    func stream(
        request: ChatGenerationRequest,
        onEvent: @escaping @MainActor @Sendable (ChatGenerationEvent) async -> Void
    ) async throws -> ChatGenerationResult {
        try await prepare()

        let (bytes, response) = try await session.bytes(for: chatCompletionURLRequest(request: request, stream: true))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.cleanupFailed(details: "llama-server returned a non-HTTP streaming response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let detail = try await Self.collectStreamingErrorBody(from: bytes)
            throw AppError.cleanupFailed(details: "llama-server streaming failed: \(detail)")
        }

        var parser = ModelOutputStreamParser()
        var content = ""
        var reasoning = ""

        for try await line in bytes.lines {
            guard let payload = Self.serverSentEventPayload(from: line) else {
                continue
            }

            if payload == "[DONE]" {
                break
            }

            guard let data = payload.data(using: .utf8) else {
                continue
            }

            let chunk = try JSONDecoder().decode(StreamingChatCompletionChunk.self, from: data)
            for choice in chunk.choices {
                if let reasoningDelta = choice.delta.reasoningText, !reasoningDelta.isEmpty {
                    if request.showsReasoning {
                        reasoning += reasoningDelta
                        await onEvent(.reasoningDelta(reasoningDelta))
                    }
                }

                guard let rawContentDelta = choice.delta.content, !rawContentDelta.isEmpty else {
                    continue
                }

                let parsedDelta = parser.consume(rawContentDelta)
                if request.showsReasoning, !parsedDelta.reasoningDelta.isEmpty {
                    reasoning += parsedDelta.reasoningDelta
                    await onEvent(.reasoningDelta(parsedDelta.reasoningDelta))
                }
                if !parsedDelta.contentDelta.isEmpty {
                    content += parsedDelta.contentDelta
                    await onEvent(.contentDelta(parsedDelta.contentDelta))
                }
            }
        }

        let finalDelta = parser.finish()
        if request.showsReasoning, !finalDelta.reasoningDelta.isEmpty {
            reasoning += finalDelta.reasoningDelta
            await onEvent(.reasoningDelta(finalDelta.reasoningDelta))
        }
        if !finalDelta.contentDelta.isEmpty {
            content += finalDelta.contentDelta
            await onEvent(.contentDelta(finalDelta.contentDelta))
        }

        return ChatGenerationResult(
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            reasoning: request.showsReasoning ? reasoning.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        )
    }

    private func generateRaw(request: ChatGenerationRequest) async throws -> String {
        try await generateChatCompletionMessage(request: request).contentText
    }

    private func generateChatCompletionMessage(
        request: ChatGenerationRequest
    ) async throws -> ChatCompletionResponse.Message {
        try await prepare()

        #if ECHOV_DEV_DIAGNOSTICS
        serverRequestCount += 1

        let diagnosticsRequestID = await PrimeDiagnostics.nextLlamaRequestID()
        let diagnosticsTotalStart = Date()
        let diagnosticsServerAge = serverReadyAt.map { diagnosticsTotalStart.timeIntervalSince($0) }
        let diagnosticsServerRequestCount = serverRequestCount
        let diagnosticsPID = process?.processIdentifier
        let diagnosticsPromptChars = request.characterCount
        #endif

        #if ECHOV_DEV_DIAGNOSTICS
        let firstStart = Date()
        #endif
        let decoded: ChatCompletionResponse
        do {
            decoded = try await performChatCompletionResponse(request: request)
        } catch {
            #if ECHOV_DEV_DIAGNOSTICS
            PrimeDiagnostics.writeLlamaFailed(
                requestID: diagnosticsRequestID,
                model: modelURL.lastPathComponent,
                pid: diagnosticsPID,
                serverAge: diagnosticsServerAge,
                serverRequestCount: diagnosticsServerRequestCount,
                promptChars: diagnosticsPromptChars,
                maxTokens: request.maxTokens,
                firstDuration: Date().timeIntervalSince(firstStart),
                retryDuration: nil,
                totalDuration: Date().timeIntervalSince(diagnosticsTotalStart),
                reason: "initial_request_error",
                emptyResponseDetail: nil
            )
            #endif
            throw error
        }

        #if ECHOV_DEV_DIAGNOSTICS
        let firstDuration = Date().timeIntervalSince(firstStart)
        #endif

        if let message = decoded.firstNonEmptyMessage {
            #if ECHOV_DEV_DIAGNOSTICS
            PrimeDiagnostics.writeLlamaCompleted(
                requestID: diagnosticsRequestID,
                model: modelURL.lastPathComponent,
                pid: diagnosticsPID,
                serverAge: diagnosticsServerAge,
                serverRequestCount: diagnosticsServerRequestCount,
                promptChars: diagnosticsPromptChars,
                maxTokens: request.maxTokens,
                outputChars: message.contentText.count,
                firstDuration: firstDuration,
                retryDuration: nil,
                totalDuration: Date().timeIntervalSince(diagnosticsTotalStart),
                emptyResponseDetail: nil
            )
            #endif
            return message
        }

        let detail = decoded.emptyResponseDetail
        DiagnosticLog.write(
            "llama-server empty response model=\(modelURL.lastPathComponent) maxTokens=\(request.maxTokens) \(detail)"
        )

        guard request.maxTokens < Self.emptyResponseRetryMaxTokens else {
            #if ECHOV_DEV_DIAGNOSTICS
            PrimeDiagnostics.writeLlamaFailed(
                requestID: diagnosticsRequestID,
                model: modelURL.lastPathComponent,
                pid: diagnosticsPID,
                serverAge: diagnosticsServerAge,
                serverRequestCount: diagnosticsServerRequestCount,
                promptChars: diagnosticsPromptChars,
                maxTokens: request.maxTokens,
                firstDuration: firstDuration,
                retryDuration: nil,
                totalDuration: Date().timeIntervalSince(diagnosticsTotalStart),
                reason: "empty_response",
                emptyResponseDetail: detail
            )
            #endif
            throw AppError.cleanupFailed(details: "llama-server returned an empty response. \(detail)")
        }

        let retryMaxTokens = min(
            Self.emptyResponseRetryMaxTokens,
            max(request.maxTokens * 2, 1536)
        )
        DiagnosticLog.write(
            "llama-server retrying empty response model=\(modelURL.lastPathComponent) maxTokens=\(retryMaxTokens)"
        )

        #if ECHOV_DEV_DIAGNOSTICS
        let retryStart = Date()
        #endif
        let retryResponse: ChatCompletionResponse
        do {
            retryResponse = try await performChatCompletionResponse(
                request: request.withMaxTokens(retryMaxTokens)
            )
        } catch {
            #if ECHOV_DEV_DIAGNOSTICS
            PrimeDiagnostics.writeLlamaFailed(
                requestID: diagnosticsRequestID,
                model: modelURL.lastPathComponent,
                pid: diagnosticsPID,
                serverAge: diagnosticsServerAge,
                serverRequestCount: diagnosticsServerRequestCount,
                promptChars: diagnosticsPromptChars,
                maxTokens: retryMaxTokens,
                firstDuration: firstDuration,
                retryDuration: Date().timeIntervalSince(retryStart),
                totalDuration: Date().timeIntervalSince(diagnosticsTotalStart),
                reason: "retry_request_error",
                emptyResponseDetail: detail
            )
            #endif
            throw error
        }

        #if ECHOV_DEV_DIAGNOSTICS
        let retryDuration = Date().timeIntervalSince(retryStart)
        #endif
        if let message = retryResponse.firstNonEmptyMessage {
            #if ECHOV_DEV_DIAGNOSTICS
            PrimeDiagnostics.writeLlamaCompleted(
                requestID: diagnosticsRequestID,
                model: modelURL.lastPathComponent,
                pid: diagnosticsPID,
                serverAge: diagnosticsServerAge,
                serverRequestCount: diagnosticsServerRequestCount,
                promptChars: diagnosticsPromptChars,
                maxTokens: retryMaxTokens,
                outputChars: message.contentText.count,
                firstDuration: firstDuration,
                retryDuration: retryDuration,
                totalDuration: Date().timeIntervalSince(diagnosticsTotalStart),
                emptyResponseDetail: detail
            )
            #endif
            return message
        }

        let retryDetail = retryResponse.emptyResponseDetail
        DiagnosticLog.write(
            "llama-server empty response after retry model=\(modelURL.lastPathComponent) maxTokens=\(retryMaxTokens) \(retryDetail)"
        )
        #if ECHOV_DEV_DIAGNOSTICS
        PrimeDiagnostics.writeLlamaFailed(
            requestID: diagnosticsRequestID,
            model: modelURL.lastPathComponent,
            pid: diagnosticsPID,
            serverAge: diagnosticsServerAge,
            serverRequestCount: diagnosticsServerRequestCount,
            promptChars: diagnosticsPromptChars,
            maxTokens: retryMaxTokens,
            firstDuration: firstDuration,
            retryDuration: retryDuration,
            totalDuration: Date().timeIntervalSince(diagnosticsTotalStart),
            reason: "empty_response_after_retry",
            emptyResponseDetail: "\(detail); retry \(retryDetail)"
        )
        #endif
        throw AppError.cleanupFailed(
            details: "llama-server returned an empty response after retry. \(retryDetail)"
        )
    }

    private func generateChatCompletionResponse(request: ChatGenerationRequest) async throws -> ChatCompletionResponse {
        try await prepare()
        return try await performChatCompletionResponse(request: request)
    }

    private func performChatCompletionResponse(request: ChatGenerationRequest) async throws -> ChatCompletionResponse {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: chatCompletionURLRequest(request: request, stream: false))
        } catch {
            DiagnosticLog.write(
                "llama-server request failed model=\(modelURL.lastPathComponent) error=\(error.localizedDescription)"
            )
            throw AppError.cleanupFailed(details: "llama-server request failed: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "No response body."
            DiagnosticLog.write(
                "llama-server generation failed model=\(modelURL.lastPathComponent) detail=\(detail)"
            )
            throw AppError.cleanupFailed(details: "llama-server generation failed: \(detail)")
        }

        do {
            return try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            DiagnosticLog.write(
                "llama-server response decode failed model=\(modelURL.lastPathComponent) error=\(error.localizedDescription)"
            )
            throw AppError.cleanupFailed(details: "llama-server response decode failed: \(error.localizedDescription)")
        }
    }

    private func chatCompletionURLRequest(request chatRequest: ChatGenerationRequest, stream: Bool) throws -> URLRequest {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(
            LlamaServerChatCompletionRequest(chatRequest: chatRequest, stream: stream)
        )

        return urlRequest
    }

    private var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)")!
    }

    func shutdown() async {
        guard let process else {
            serverState = .idle
            return
        }

        self.process = nil
        serverState = .idle
        #if ECHOV_DEV_DIAGNOSTICS
        serverReadyAt = nil
        serverRequestCount = 0
        #endif

        guard process.isRunning else {
            return
        }

        DiagnosticLog.write("llama-server shutdown requested pid=\(process.processIdentifier)")

        process.terminate()
        await waitForExit(process, timeout: 2)

        guard process.isRunning else {
            DiagnosticLog.write("llama-server terminated pid=\(process.processIdentifier)")
            return
        }

        Darwin.kill(process.processIdentifier, SIGKILL)
        await waitForExit(process, timeout: 1)

        if process.isRunning {
            DiagnosticLog.write("llama-server force kill requested but process is still running pid=\(process.processIdentifier)")
        } else {
            DiagnosticLog.write("llama-server force killed pid=\(process.processIdentifier)")
        }
    }

    private func waitForExit(_ process: Process, timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
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

    private static func availableLoopbackPort() -> Int {
        let socketDescriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            return Int.random(in: 49_152...65_535)
        }
        defer {
            Darwin.close(socketDescriptor)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(0).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.bind(socketDescriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            return Int.random(in: 49_152...65_535)
        }

        var boundAddress = sockaddr_in()
        var boundLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.getsockname(socketDescriptor, sockaddrPointer, &boundLength)
            }
        }
        guard nameResult == 0 else {
            return Int.random(in: 49_152...65_535)
        }

        return Int(in_port_t(bigEndian: boundAddress.sin_port))
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

    private static func serverSentEventPayload(from line: String) -> String? {
        guard line.hasPrefix("data:") else {
            return nil
        }

        return line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func collectStreamingErrorBody(from bytes: URLSession.AsyncBytes) async throws -> String {
        var body = ""
        for try await line in bytes.lines {
            body += line
            body += "\n"
        }

        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No response body." : trimmed
    }
}

struct LlamaServerChatCompletionRequest: Encodable {
    let messages: [LlamaServerChatCompletionMessage]
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let stream: Bool
    let chatTemplateKwargs: ChatTemplateKwargs?

    init(chatRequest: ChatGenerationRequest, stream: Bool) {
        self.messages = chatRequest.messages.map { message in
            LlamaServerChatCompletionMessage(role: message.role.rawValue, content: message.content)
        }
        self.temperature = chatRequest.temperature
        self.topP = chatRequest.topP
        self.maxTokens = chatRequest.maxTokens
        self.stream = stream
        self.chatTemplateKwargs = chatRequest.showsReasoning ? nil : .disableThinking
    }

    enum CodingKeys: String, CodingKey {
        case messages
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case stream
        case chatTemplateKwargs = "chat_template_kwargs"
    }

    struct ChatTemplateKwargs: Encodable {
        static let disableThinking = ChatTemplateKwargs(enableThinking: false)

        let enableThinking: Bool

        enum CodingKeys: String, CodingKey {
            case enableThinking = "enable_thinking"
        }
    }
}

struct LlamaServerChatCompletionMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct Message: Decodable {
        let content: String?
        let reasoning: String?
        let reasoningContent: String?

        var contentText: String {
            content ?? ""
        }

        var reasoningText: String? {
            reasoningContent ?? reasoning
        }

        enum CodingKeys: String, CodingKey {
            case content
            case reasoning
            case reasoningContent = "reasoning_content"
        }
    }
}

private extension ChatCompletionResponse {
    var firstNonEmptyMessage: Message? {
        choices.map(\.message).first { message in
            !message.contentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var emptyResponseDetail: String {
        let contentCharacters = choices.reduce(0) { partialResult, choice in
            partialResult + choice.message.contentText.count
        }
        let reasoningCharacters = choices.reduce(0) { partialResult, choice in
            partialResult + (choice.message.reasoningText?.count ?? 0)
        }
        let finishReasons = choices
            .compactMap(\.finishReason)
            .filter { !$0.isEmpty }
            .joined(separator: ",")

        return "choices=\(choices.count) contentChars=\(contentCharacters) reasoningChars=\(reasoningCharacters) finishReasons=\(finishReasons.isEmpty ? "none" : finishReasons)"
    }
}

private extension ChatGenerationRequest {
    #if ECHOV_DEV_DIAGNOSTICS
    var characterCount: Int {
        messages.reduce(0) { partialResult, message in
            partialResult + message.content.count
        }
    }
    #endif

    func withMaxTokens(_ maxTokens: Int) -> ChatGenerationRequest {
        ChatGenerationRequest(
            messages: messages,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            policy: policy
        )
    }
}

private struct StreamingChatCompletionChunk: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
    }

    struct Delta: Decodable {
        let content: String?
        let reasoning: String?
        let reasoningContent: String?

        var reasoningText: String? {
            reasoningContent ?? reasoning
        }

        enum CodingKeys: String, CodingKey {
            case content
            case reasoning
            case reasoningContent = "reasoning_content"
        }
    }
}
