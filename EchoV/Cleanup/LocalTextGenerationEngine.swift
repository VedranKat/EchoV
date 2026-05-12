import Foundation

protocol LocalTextGenerationEngine: Sendable {
    var id: String { get }
    var displayName: String { get }

    func prepare() async throws
    func generate(prompt: PrimeCleanupPrompt) async throws -> String
    func shutdown() async
}

extension LocalTextGenerationEngine {
    func shutdown() async {}
}

struct UnconfiguredLocalTextGenerationEngine: LocalTextGenerationEngine {
    let id = "unconfigured"
    let displayName = "No Local Text Model"

    func prepare() async throws {
        throw AppError.cleanupModelNotConfigured
    }

    func generate(prompt: PrimeCleanupPrompt) async throws -> String {
        throw AppError.cleanupModelNotConfigured
    }
}

struct Gemma4LocalTextGenerationEngine: LocalTextGenerationEngine {
    let id = "gemma-4-e2b-it"
    let displayName = "Gemma 4 E2B IT"

    private let runtime: LlamaServerTextGenerationEngine

    init(modelURL: URL, runtimeURL: URL?) {
        guard let ggufModelURL = Gemma4PostProcessingModelLayout.ggufModelFileCandidate(for: modelURL) else {
            self.runtime = LlamaServerTextGenerationEngine(modelURL: modelURL, runtimeURL: runtimeURL)
            return
        }

        self.runtime = LlamaServerTextGenerationEngine(modelURL: ggufModelURL, runtimeURL: runtimeURL)
    }

    func prepare() async throws {
        try await runtime.prepare()
    }

    func generate(prompt: PrimeCleanupPrompt) async throws -> String {
        try await runtime.generate(prompt: prompt)
    }

    func shutdown() async {
        await runtime.shutdown()
    }
}
