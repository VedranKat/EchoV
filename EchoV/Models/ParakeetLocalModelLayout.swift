import Foundation

enum ParakeetLocalModelLayout {
    static let expectedFolderName = "parakeet-tdt-0.6b-v3-coreml"
    static let legacyFolderName = "parakeet-tdt-0.6b-v3"

    static let requiredFiles = [
        "Preprocessor.mlmodelc/coremldata.bin",
        "Encoder.mlmodelc/coremldata.bin",
        "Decoder.mlmodelc/coremldata.bin",
        "JointDecisionv3.mlmodelc/coremldata.bin",
        "parakeet_vocab.json"
    ]

    static let requiredModelBundles = [
        "Preprocessor.mlmodelc",
        "Encoder.mlmodelc",
        "Decoder.mlmodelc",
        "JointDecisionv3.mlmodelc"
    ]

    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func missingFiles(at url: URL) -> [String] {
        requiredFiles.filter { relativePath in
            !FileManager.default.fileExists(atPath: url.appendingPathComponent(relativePath).path)
        }
    }

    static func missingModelBundles(at url: URL) -> [String] {
        requiredModelBundles.filter { relativePath in
            !FileManager.default.fileExists(atPath: url.appendingPathComponent(relativePath).path)
        }
    }

    static func containsRequiredFiles(at url: URL) -> Bool {
        missingFiles(at: url).isEmpty
    }

    static func modelFolderCandidate(for selectedURL: URL) -> URL? {
        existingModelFolderCandidates(for: selectedURL).first { containsRequiredFiles(at: $0) }
    }

    static func existingModelFolderCandidates(for selectedURL: URL) -> [URL] {
        candidateURLs(for: selectedURL).filter(isDirectory)
    }

    static func localFluidAudioFolder(for selectedURL: URL) throws -> URL {
        guard let candidateURL = modelFolderCandidate(for: selectedURL) else {
            let closestModelURL = existingModelFolderCandidates(for: selectedURL).first ?? selectedURL
            let missing = missingFiles(at: closestModelURL)
            let detail = missing.isEmpty
                ? "Select the local \(expectedFolderName) folder, or a parent folder containing it."
                : "Missing local model files: \(missing.joined(separator: ", "))"
            throw AppError.modelPathInvalid(details: detail)
        }

        guard candidateURL.lastPathComponent != expectedFolderName else {
            try validateFluidAudioLoadPath(candidateURL)
            return candidateURL
        }

        let linkURL = try createExpectedFolderSymlink(to: candidateURL)
        try validateFluidAudioLoadPath(linkURL)
        return linkURL
    }

    private static func candidateURLs(for selectedURL: URL) -> [URL] {
        var candidates = [selectedURL]

        if selectedURL.lastPathComponent != expectedFolderName {
            candidates.append(selectedURL.appendingPathComponent(expectedFolderName, isDirectory: true))
        }

        if selectedURL.lastPathComponent != legacyFolderName {
            candidates.append(selectedURL.appendingPathComponent(legacyFolderName, isDirectory: true))
        }

        return candidates
    }

    private static func createExpectedFolderSymlink(to modelURL: URL) throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let linkDirectory = appSupport.appendingPathComponent("EchoV/ModelLinks", isDirectory: true)
        try FileManager.default.createDirectory(at: linkDirectory, withIntermediateDirectories: true)

        let linkURL = linkDirectory.appendingPathComponent(expectedFolderName, isDirectory: true)

        if FileManager.default.fileExists(atPath: linkURL.path) {
            try FileManager.default.removeItem(at: linkURL)
        }

        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: modelURL)
        return linkURL
    }

    private static func validateFluidAudioLoadPath(_ url: URL) throws {
        let missingBundles = missingModelBundles(at: url)
        let missingFiles = missingFiles(at: url)
        let missing = missingBundles + missingFiles.filter { file in
            !missingBundles.contains { bundle in file.hasPrefix(bundle) }
        }

        guard missing.isEmpty else {
            throw AppError.modelPathInvalid(
                details: "FluidAudio local load path is incomplete: \(missing.joined(separator: ", "))"
            )
        }
    }
}
