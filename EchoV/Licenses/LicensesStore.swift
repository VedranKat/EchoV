import Foundation

struct LicensesStore: Sendable {
    let notices: [ThirdPartyNotice] = [
        ThirdPartyNotice(
            id: "fluid-audio",
            name: "FluidAudio SDK",
            licenseName: "Apache-2.0",
            notice: "Used for local speech transcription when FluidAudio support is enabled."
        ),
        ThirdPartyNotice(
            id: "parakeet-v3",
            name: "Parakeet v3 model",
            licenseName: "CC-BY-4.0",
            notice: "Supported as a local user-selected ASR model. Attribution is required when distributed, downloaded, recommended, or directly supported."
        ),
        ThirdPartyNotice(
            id: "llama-cpp",
            name: "llama.cpp",
            licenseName: "MIT",
            notice: "Used as the downloadable or user-selected local GGUF inference runtime for Gemma post-processing. Copyright (c) 2023-2026 The ggml authors."
        )
    ]
}
