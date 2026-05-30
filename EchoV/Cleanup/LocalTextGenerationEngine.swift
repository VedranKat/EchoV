import Foundation

protocol LocalTextGenerationEngine: Sendable {
    var id: String { get }
    var displayName: String { get }

    func prepare() async throws
    func generate(prompt: LocalChatPrompt) async throws -> String
    func generate(request: ChatGenerationRequest) async throws -> ChatGenerationResult
    func stream(
        request: ChatGenerationRequest,
        onEvent: @escaping @MainActor @Sendable (ChatGenerationEvent) async -> Void
    ) async throws -> ChatGenerationResult
    func shutdown() async
}

extension LocalTextGenerationEngine {
    func generate(request: ChatGenerationRequest) async throws -> ChatGenerationResult {
        let rawOutput = try await generate(prompt: request.legacyPrompt)
        return ChatGenerationResult.fromRawOutput(rawOutput, policy: request.policy)
    }

    func stream(
        request: ChatGenerationRequest,
        onEvent: @escaping @MainActor @Sendable (ChatGenerationEvent) async -> Void
    ) async throws -> ChatGenerationResult {
        let result = try await generate(request: request)
        if !result.reasoning.isEmpty {
            await onEvent(.reasoningDelta(result.reasoning))
        }
        if !result.content.isEmpty {
            await onEvent(.contentDelta(result.content))
        }
        return result
    }

    func shutdown() async {}
}

struct UnconfiguredLocalTextGenerationEngine: LocalTextGenerationEngine {
    let id = "unconfigured"
    let displayName = "No Local Text Model"

    func prepare() async throws {
        throw AppError.cleanupModelNotConfigured
    }

    func generate(prompt: LocalChatPrompt) async throws -> String {
        throw AppError.cleanupModelNotConfigured
    }
}

struct Gemma4LocalTextGenerationEngine: LocalTextGenerationEngine {
    let id: String
    let displayName: String

    private let runtime: LlamaServerTextGenerationEngine

    init(
        modelURL: URL,
        runtimeURL: URL?,
        modelDefinition: PostProcessingModelDefinition = .defaultModel,
        displayName: String? = nil
    ) {
        self.id = modelDefinition.id
        self.displayName = displayName ?? modelDefinition.displayName

        guard let ggufModelURL = Gemma4PostProcessingModelLayout.ggufModelFileCandidate(
            for: modelURL,
            definition: modelDefinition
        ) else {
            self.runtime = LlamaServerTextGenerationEngine(modelURL: modelURL, runtimeURL: runtimeURL)
            return
        }

        self.runtime = LlamaServerTextGenerationEngine(modelURL: ggufModelURL, runtimeURL: runtimeURL)
    }

    func prepare() async throws {
        try await runtime.prepare()
    }

    func generate(prompt: LocalChatPrompt) async throws -> String {
        try await runtime.generate(prompt: prompt)
    }

    func generate(request: ChatGenerationRequest) async throws -> ChatGenerationResult {
        try await runtime.generate(request: request)
    }

    func stream(
        request: ChatGenerationRequest,
        onEvent: @escaping @MainActor @Sendable (ChatGenerationEvent) async -> Void
    ) async throws -> ChatGenerationResult {
        try await runtime.stream(request: request, onEvent: onEvent)
    }

    func shutdown() async {
        await runtime.shutdown()
    }
}
