import Foundation

struct OpenAICompatibleVoiceModeTextGenerationEngine: LocalTextGenerationEngine {
    let id = "openai-compatible-cloud"
    let displayName = "OpenAI-compatible Cloud"

    private let baseURL: @MainActor @Sendable () -> String
    private let model: @MainActor @Sendable () -> String
    private let apiKey: @MainActor @Sendable () -> String
    private let proxySettings: @MainActor @Sendable () -> ProxySettings

    init(
        baseURL: @escaping @MainActor @Sendable () -> String,
        model: @escaping @MainActor @Sendable () -> String,
        apiKey: @escaping @MainActor @Sendable () -> String,
        proxySettings: @escaping @MainActor @Sendable () -> ProxySettings
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.proxySettings = proxySettings
    }

    func prepare() async throws {
        _ = try await configuration()
    }

    func generate(prompt: LocalChatPrompt) async throws -> String {
        let request = prompt.chatGenerationRequest(policy: .chat(stream: false, showReasoning: true))
        return try await generateRaw(request: request)
    }

    func generate(request: ChatGenerationRequest) async throws -> ChatGenerationResult {
        let response = try await generateChatCompletionResponse(request: request)
        guard let message = response.choices.first?.message,
              !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AppError.voiceModeResponseFailed(details: "Cloud provider returned an empty response.")
        }

        let parsedContent = ChatGenerationResult.fromRawOutput(message.content, policy: request.policy)
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
        let configuration = try await configuration()
        let session = try await makeSession()
        defer {
            session.finishTasksAndInvalidate()
        }

        let (bytes, response) = try await session.bytes(for: chatCompletionURLRequest(
            configuration: configuration,
            request: request,
            stream: true
        ))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.voiceModeResponseFailed(details: "Cloud provider returned a non-HTTP streaming response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let detail = try await Self.collectStreamingErrorBody(from: bytes)
            throw AppError.voiceModeResponseFailed(
                details: "Cloud provider returned HTTP \(httpResponse.statusCode): \(detail)"
            )
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

            let chunk = try JSONDecoder().decode(OpenAICompatibleStreamingChatCompletionChunk.self, from: data)
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
        let decoded = try await generateChatCompletionResponse(request: request)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty
        else {
            throw AppError.voiceModeResponseFailed(details: "Cloud provider returned an empty response.")
        }

        return content
    }

    private func generateChatCompletionResponse(request: ChatGenerationRequest) async throws -> OpenAICompatibleChatCompletionResponse {
        let configuration = try await configuration()
        let session = try await makeSession()
        defer {
            session.finishTasksAndInvalidate()
        }

        let (data, response) = try await session.data(for: chatCompletionURLRequest(
            configuration: configuration,
            request: request,
            stream: false
        ))
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.voiceModeResponseFailed(details: "Cloud provider returned a non-HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let detail = Self.responseDetail(from: data)
            throw AppError.voiceModeResponseFailed(
                details: "Cloud provider returned HTTP \(httpResponse.statusCode): \(detail)"
            )
        }

        return try JSONDecoder().decode(OpenAICompatibleChatCompletionResponse.self, from: data)
    }

    private func makeSession() async throws -> URLSession {
        let proxySettings = await proxySettings()
        guard proxySettings.isValid else {
            throw AppError.voiceModeResponseFailed(
                details: "Proxy settings are incomplete. Enter host names and ports from 1 to 65535."
            )
        }

        return ProxyURLSessionFactory(proxySettings: proxySettings).makeSession()
    }

    private func chatCompletionURLRequest(
        configuration: Configuration,
        request chatRequest: ChatGenerationRequest,
        stream: Bool
    ) throws -> URLRequest {
        var urlRequest = URLRequest(url: configuration.chatCompletionsURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(OpenAICompatibleChatCompletionRequest(
            model: configuration.model,
            messages: chatRequest.messages.map { message in
                OpenAICompatibleChatCompletionMessage(role: message.role.rawValue, content: message.content)
            },
            temperature: chatRequest.temperature,
            topP: chatRequest.topP,
            maxTokens: chatRequest.maxTokens,
            stream: stream
        ))

        return urlRequest
    }

    private func configuration() async throws -> Configuration {
        let baseURL = await baseURL().trimmingCharacters(in: .whitespacesAndNewlines)
        let model = await model().trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = await apiKey().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !baseURL.isEmpty, let url = URL(string: baseURL), url.scheme != nil, url.host != nil else {
            throw AppError.voiceModeResponseNotConfigured
        }

        guard !model.isEmpty, !apiKey.isEmpty else {
            throw AppError.voiceModeResponseNotConfigured
        }

        return Configuration(
            chatCompletionsURL: Self.chatCompletionsURL(from: url),
            model: model,
            apiKey: apiKey
        )
    }

    private static func chatCompletionsURL(from baseURL: URL) -> URL {
        let normalizedPath = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalizedPath.hasSuffix("chat/completions") {
            return baseURL
        }

        return baseURL.appendingPathComponent("chat/completions")
    }

    private static func responseDetail(from data: Data) -> String {
        guard !data.isEmpty else {
            return "No response body."
        }

        if
            let decoded = try? JSONDecoder().decode(OpenAICompatibleErrorResponse.self, from: data),
            let message = decoded.error?.message,
            !message.isEmpty
        {
            return message
        }

        return String(data: data, encoding: .utf8) ?? "Unreadable response body."
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

    private struct Configuration {
        let chatCompletionsURL: URL
        let model: String
        let apiKey: String
    }
}

private struct OpenAICompatibleChatCompletionRequest: Encodable {
    let model: String
    let messages: [OpenAICompatibleChatCompletionMessage]
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case topP = "top_p"
        case maxTokens = "max_tokens"
        case stream
    }
}

private struct OpenAICompatibleChatCompletionMessage: Encodable {
    let role: String
    let content: String
}

private struct OpenAICompatibleChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
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

private struct OpenAICompatibleStreamingChatCompletionChunk: Decodable {
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

private struct OpenAICompatibleErrorResponse: Decodable {
    let error: ErrorBody?

    struct ErrorBody: Decodable {
        let message: String?
    }
}
