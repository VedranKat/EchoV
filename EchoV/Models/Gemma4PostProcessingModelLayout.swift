import Foundation

enum Gemma4PostProcessingModelLayout {
    static let modelID = PostProcessingModelDefinition.defaultModel.modelID
    static let ggufRepositoryID = PostProcessingModelDefinition.defaultModel.ggufRepositoryID
    static let displayName = PostProcessingModelDefinition.defaultModel.displayName
    static let expectedFolderName = PostProcessingModelDefinition.defaultModel.expectedFolderName
    static let ggufFileName = PostProcessingModelDefinition.defaultModel.ggufFileName
    static let modelPageURL = PostProcessingModelDefinition.defaultModel.modelPageURL
    static let downloadURL = PostProcessingModelDefinition.defaultModel.downloadURL

    static var managedModelURL: URL {
        managedModelURL(for: .defaultModel)
    }

    static func managedModelURL(for definition: PostProcessingModelDefinition) -> URL {
        managedModelsDirectory.appendingPathComponent(definition.expectedFolderName, isDirectory: true)
    }

    static var managedModelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EchoV/Models/PostProcessing", isDirectory: true)
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func modelFolderCandidate(
        for selectedURL: URL,
        definition: PostProcessingModelDefinition = .defaultModel
    ) -> URL? {
        existingModelFolderCandidates(for: selectedURL, definition: definition)
            .first { containsSupportedModelFiles(at: $0) }
    }

    static func ggufModelFileCandidate(
        for selectedURL: URL,
        definition: PostProcessingModelDefinition = .defaultModel
    ) -> URL? {
        if selectedURL.pathExtension.lowercased() == "gguf" {
            return selectedURL
        }

        guard let modelFolderURL = modelFolderCandidate(for: selectedURL, definition: definition) else {
            return nil
        }

        let preferredURL = modelFolderURL.appendingPathComponent(definition.ggufFileName)
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

    static func existingModelFolderCandidates(
        for selectedURL: URL,
        definition: PostProcessingModelDefinition = .defaultModel
    ) -> [URL] {
        if selectedURL.pathExtension.lowercased() == "gguf" {
            return [selectedURL.deletingLastPathComponent()].filter(isDirectory)
        }

        return candidateURLs(for: selectedURL, definition: definition).filter(isDirectory)
    }

    static func missingFilesMessage(
        at url: URL,
        definition: PostProcessingModelDefinition = .defaultModel
    ) -> String {
        if containsGGUFModel(at: url) {
            return "Found GGUF model weights."
        }

        return "Expected a \(definition.displayName) GGUF file for llama.cpp."
    }

    static func managedModelDefinition(for url: URL) -> PostProcessingModelDefinition? {
        let candidateURL = url.pathExtension.lowercased() == "gguf"
            ? url.deletingLastPathComponent()
            : url
        let candidatePath = candidateURL.standardizedFileURL.path

        return PostProcessingModelDefinition.allCases.first { definition in
            managedModelURL(for: definition).standardizedFileURL.path == candidatePath
        }
    }

    static func isManagedModelURL(
        _ url: URL,
        for definition: PostProcessingModelDefinition
    ) -> Bool {
        managedModelDefinition(for: url) == definition
    }

    private static func candidateURLs(
        for selectedURL: URL,
        definition: PostProcessingModelDefinition
    ) -> [URL] {
        if selectedURL.lastPathComponent == definition.expectedFolderName {
            return [selectedURL]
        }

        return [
            selectedURL.appendingPathComponent(definition.expectedFolderName, isDirectory: true),
            selectedURL.appendingPathComponent(definition.modelID, isDirectory: true),
            selectedURL.appendingPathComponent(definition.ggufRepositoryID, isDirectory: true),
            selectedURL
        ]
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
