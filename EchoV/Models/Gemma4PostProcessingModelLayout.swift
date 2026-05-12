import Foundation

enum Gemma4PostProcessingModelLayout {
    static let modelID = "google/gemma-4-E2B-it"
    static let ggufRepositoryID = "unsloth/gemma-4-E2B-it-GGUF"
    static let displayName = "Gemma 4 E2B IT"
    static let expectedFolderName = "gemma-4-E2B-it"
    static let ggufFileName = "gemma-4-E2B-it-Q4_K_M.gguf"
    static let modelPageURL = URL(string: "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF")!
    static let downloadURL = URL(string: "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf")!

    static var managedModelURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EchoV/Models/PostProcessing", isDirectory: true)
            .appendingPathComponent(expectedFolderName, isDirectory: true)
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func modelFolderCandidate(for selectedURL: URL) -> URL? {
        existingModelFolderCandidates(for: selectedURL).first { containsSupportedModelFiles(at: $0) }
    }

    static func ggufModelFileCandidate(for selectedURL: URL) -> URL? {
        if selectedURL.pathExtension.lowercased() == "gguf" {
            return selectedURL
        }

        guard let modelFolderURL = modelFolderCandidate(for: selectedURL) else {
            return nil
        }

        let preferredURL = modelFolderURL.appendingPathComponent(ggufFileName)
        if FileManager.default.fileExists(atPath: preferredURL.path) {
            return preferredURL
        }

        guard let enumerator = FileManager.default.enumerator(
            at: modelFolderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "gguf" {
                return fileURL
            }
        }

        return nil
    }

    static func existingModelFolderCandidates(for selectedURL: URL) -> [URL] {
        if selectedURL.pathExtension.lowercased() == "gguf" {
            return [selectedURL.deletingLastPathComponent()].filter(isDirectory)
        }

        return candidateURLs(for: selectedURL).filter(isDirectory)
    }

    static func missingFilesMessage(at url: URL) -> String {
        if containsGGUFModel(at: url) {
            return "Found GGUF model weights."
        }

        return "Expected a Gemma 4 E2B GGUF file for llama.cpp."
    }

    private static func candidateURLs(for selectedURL: URL) -> [URL] {
        var candidates = [selectedURL]

        if selectedURL.lastPathComponent != expectedFolderName {
            candidates.append(selectedURL.appendingPathComponent(expectedFolderName, isDirectory: true))
        }

        if selectedURL.lastPathComponent != modelID {
            candidates.append(selectedURL.appendingPathComponent(modelID, isDirectory: true))
        }

        return candidates
    }

    private static func containsSupportedModelFiles(at url: URL) -> Bool {
        containsGGUFModel(at: url)
    }

    private static func containsGGUFModel(at url: URL) -> Bool {
        if url.pathExtension.lowercased() == "gguf" {
            return true
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return false
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension.lowercased() == "gguf" {
                return true
            }
        }

        return false
    }
}
