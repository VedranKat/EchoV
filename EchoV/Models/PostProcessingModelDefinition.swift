import Foundation

struct PostProcessingModelDefinition: Identifiable, CaseIterable, Equatable, Hashable, Sendable {
    let id: String
    let modelID: String
    let ggufRepositoryID: String
    let displayName: String
    let shortName: String
    let expectedFolderName: String
    let ggufFileName: String
    let modelPageURL: URL
    let downloadURL: URL
    let quantization: String
    let summary: String

    static let gemma4E2B = PostProcessingModelDefinition(
        id: "gemma-4-e2b-it",
        modelID: "google/gemma-4-E2B-it",
        ggufRepositoryID: "unsloth/gemma-4-E2B-it-GGUF",
        displayName: "Gemma 4 E2B IT",
        shortName: "E2B",
        expectedFolderName: "gemma-4-E2B-it",
        ggufFileName: "gemma-4-E2B-it-Q4_K_M.gguf",
        modelPageURL: URL(string: "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF")!,
        downloadURL: URL(string: "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf")!,
        quantization: "Q4_K_M",
        summary: "Faster, smaller local cleanup model."
    )

    static let gemma4E4B = PostProcessingModelDefinition(
        id: "gemma-4-e4b-it",
        modelID: "google/gemma-4-E4B-it",
        ggufRepositoryID: "unsloth/gemma-4-E4B-it-GGUF",
        displayName: "Gemma 4 E4B IT",
        shortName: "E4B",
        expectedFolderName: "gemma-4-E4B-it",
        ggufFileName: "gemma-4-E4B-it-Q4_K_M.gguf",
        modelPageURL: URL(string: "https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF")!,
        downloadURL: URL(string: "https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-Q4_K_M.gguf")!,
        quantization: "Q4_K_M",
        summary: "Higher quality local cleanup model."
    )

    static let allCases: [PostProcessingModelDefinition] = [
        .gemma4E2B,
        .gemma4E4B
    ]

    static let defaultModel = gemma4E2B

    static func definition(forID id: String) -> PostProcessingModelDefinition? {
        allCases.first { $0.id == id }
    }
}
