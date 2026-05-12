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
            id: "gemma-4-e2b-it-gguf",
            name: "Gemma 4 E2B IT GGUF",
            licenseName: "Apache-2.0",
            notice: "Used as the downloadable or user-selected local post-processing model. Source: unsloth/gemma-4-E2B-it-GGUF, derived from Google DeepMind Gemma 4 E2B IT."
        ),
        ThirdPartyNotice(
            id: "llama-cpp",
            name: "llama.cpp",
            licenseName: "MIT",
            notice: "Used as the downloadable or user-selected local GGUF inference runtime for Gemma post-processing. Copyright (c) 2023-2026 The ggml authors."
        ),
        ThirdPartyNotice(
            id: "cpp-httplib",
            name: "cpp-httplib",
            licenseName: "MIT",
            notice: "Bundled with llama.cpp and used by llama-server for local HTTP serving."
        ),
        ThirdPartyNotice(
            id: "nlohmann-json",
            name: "nlohmann/json",
            licenseName: "MIT",
            notice: "Bundled with llama.cpp for JSON handling in tools and server components."
        ),
        ThirdPartyNotice(
            id: "stb-image",
            name: "stb_image",
            licenseName: "Public Domain",
            notice: "Bundled with llama.cpp as a single-header image decoder."
        ),
        ThirdPartyNotice(
            id: "miniaudio",
            name: "miniaudio",
            licenseName: "Public Domain",
            notice: "Bundled with llama.cpp as a single-header audio decoder."
        ),
        ThirdPartyNotice(
            id: "subprocess",
            name: "subprocess.h",
            licenseName: "Public Domain",
            notice: "Bundled with llama.cpp as a single-header process launching helper."
        ),
        ThirdPartyNotice(
            id: "vbx",
            name: "VBx",
            licenseName: "Apache-2.0",
            notice: "Bundled with FluidAudio for speaker diarization clustering. Copyright 2021-2024 BUT Speech@FIT."
        ),
        ThirdPartyNotice(
            id: "fastcluster",
            name: "fastcluster",
            licenseName: "BSD-2-Clause",
            notice: "Bundled with FluidAudio for hierarchical clustering. Copyright (c) 2011 Daniel Mullner and later Google Inc."
        )
    ]
}
