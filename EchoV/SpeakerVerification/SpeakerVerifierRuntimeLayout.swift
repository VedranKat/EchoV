import Foundation

struct SpeakerVerifierRuntimeDownloadFile: Equatable, Sendable {
    let relativePath: String
    let displayName: String
    let expectedSHA256: String
}

enum SpeakerVerifierRuntimeLayout {
    static let version = "ecapa-speaker-v1"
    static let displayName = "Speaker verifier model \(version)"
    static let modelID = "speechbrain/spkrec-ecapa-voxceleb-onnx"

    static var downloadBaseURL: URL? {
        if let override = ProcessInfo.processInfo.environment["ECHOV_SPEAKER_VERIFIER_MODEL_BASE_URL"], !override.isEmpty {
            return URL(string: override)
        }

        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "EchoVSpeakerVerifierModelBaseURL") as? String,
            !value.isEmpty
        else {
            return nil
        }

        return URL(string: value)
    }

    static var manifestSHA256: String {
        if let override = ProcessInfo.processInfo.environment["ECHOV_SPEAKER_VERIFIER_MANIFEST_SHA256"], !override.isEmpty {
            return override
        }

        return Bundle.main.object(forInfoDictionaryKey: "EchoVSpeakerVerifierManifestSHA256") as? String ?? ""
    }

    static var modelSHA256: String {
        if let override = ProcessInfo.processInfo.environment["ECHOV_SPEAKER_VERIFIER_ONNX_SHA256"], !override.isEmpty {
            return override
        }

        return Bundle.main.object(forInfoDictionaryKey: "EchoVSpeakerVerifierONNXSHA256") as? String ?? ""
    }

    static var fbankSHA256: String {
        if let override = ProcessInfo.processInfo.environment["ECHOV_SPEAKER_VERIFIER_FBANK_SHA256"], !override.isEmpty {
            return override
        }

        return Bundle.main.object(forInfoDictionaryKey: "EchoVSpeakerVerifierFbankSHA256") as? String ?? ""
    }

    static var downloadFiles: [SpeakerVerifierRuntimeDownloadFile] {
        [
            SpeakerVerifierRuntimeDownloadFile(
                relativePath: "manifest.json",
                displayName: "speaker verifier manifest",
                expectedSHA256: manifestSHA256
            ),
            SpeakerVerifierRuntimeDownloadFile(
                relativePath: "model/ecapa-speaker-v1.onnx",
                displayName: "speaker verifier ONNX model",
                expectedSHA256: modelSHA256
            ),
            SpeakerVerifierRuntimeDownloadFile(
                relativePath: "model/fbank-80x201-f32.bin",
                displayName: "speaker verifier fbank table",
                expectedSHA256: fbankSHA256
            )
        ]
    }

    static func downloadURL(for file: SpeakerVerifierRuntimeDownloadFile, baseURL: URL) -> URL? {
        file.relativePath
            .split(separator: "/")
            .reduce(baseURL) { url, component in
                url.appendingPathComponent(String(component))
            }
    }

    static var managedRuntimeURL: URL {
        if let override = ProcessInfo.processInfo.environment["ECHOV_SPEAKER_VERIFIER_RUNTIME_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EchoV/Runtimes/speaker-verifier", isDirectory: true)
    }

    static var bundledSupportRuntimeURL: URL? {
        if let override = ProcessInfo.processInfo.environment["ECHOV_SPEAKER_VERIFIER_SUPPORT_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }

        return Bundle.main.resourceURL?
            .appendingPathComponent("SpeakerVerifierRuntime", isDirectory: true)
    }

    static var manifestURL: URL {
        managedRuntimeURL.appendingPathComponent("manifest.json")
    }

    static var modelURL: URL {
        managedRuntimeURL
            .appendingPathComponent("model", isDirectory: true)
            .appendingPathComponent("ecapa-speaker-v1.onnx")
    }

    static var fbankURL: URL {
        managedRuntimeURL
            .appendingPathComponent("model", isDirectory: true)
            .appendingPathComponent("fbank-80x201-f32.bin")
    }

    static var libraryDirectoryURL: URL {
        if let supportURL = bundledSupportRuntimeURL,
           onnxRuntimeLibraryCandidate(in: supportURL) != nil {
            return supportURL.appendingPathComponent("lib", isDirectory: true)
        }

        return managedRuntimeURL.appendingPathComponent("lib", isDirectory: true)
    }

    static var executableURL: URL? {
        if let supportURL = bundledSupportRuntimeURL,
           let executableURL = speakerVerifierCandidate(in: supportURL) {
            return executableURL
        }

        return speakerVerifierCandidate(in: managedRuntimeURL)
    }

    static func isInstalled() -> Bool {
        executableURL != nil
            && FileManager.default.fileExists(atPath: manifestURL.path)
            && FileManager.default.fileExists(atPath: modelURL.path)
            && FileManager.default.fileExists(atPath: fbankURL.path)
            && onnxRuntimeLibraryCandidate(in: libraryDirectoryURL.deletingLastPathComponent()) != nil
    }

    static func isBundledSupportRuntimeAvailable() -> Bool {
        guard let supportURL = bundledSupportRuntimeURL else {
            return false
        }

        return speakerVerifierCandidate(in: supportURL) != nil
            && onnxRuntimeLibraryCandidate(in: supportURL) != nil
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func speakerVerifierCandidate(in url: URL) -> URL? {
        let directURL = url.appendingPathComponent("bin/speaker-verifier")
        if FileManager.default.isExecutableFile(atPath: directURL.path) {
            return directURL
        }

        let legacyDirectURL = url.appendingPathComponent("speaker-verifier")
        if FileManager.default.isExecutableFile(atPath: legacyDirectURL.path) {
            return legacyDirectURL
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "speaker-verifier" {
            if FileManager.default.isExecutableFile(atPath: fileURL.path) {
                return fileURL
            }
        }

        return nil
    }

    static func onnxRuntimeLibraryCandidate(in url: URL) -> URL? {
        let libraryRoot = url.appendingPathComponent("lib", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: libraryRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            if name.hasPrefix("libonnxruntime") && (name.hasSuffix(".dylib") || name.contains(".dylib.")) {
                return fileURL
            }
        }

        return nil
    }

    static func missingFiles(at url: URL) -> [String] {
        var missing: [String] = []

        if !FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) {
            missing.append("manifest.json")
        }

        if !FileManager.default.fileExists(atPath: url.appendingPathComponent("model/ecapa-speaker-v1.onnx").path) {
            missing.append("model/ecapa-speaker-v1.onnx")
        }

        if !FileManager.default.fileExists(atPath: url.appendingPathComponent("model/fbank-80x201-f32.bin").path) {
            missing.append("model/fbank-80x201-f32.bin")
        }

        if !isBundledSupportRuntimeAvailable() && speakerVerifierCandidate(in: url) == nil {
            missing.append("bin/speaker-verifier")
        }

        if !isBundledSupportRuntimeAvailable() && onnxRuntimeLibraryCandidate(in: url) == nil {
            missing.append("lib/onnxruntime")
        }

        return missing
    }

    static func isModelPackage(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path)
            && FileManager.default.fileExists(atPath: url.appendingPathComponent("model/ecapa-speaker-v1.onnx").path)
            && FileManager.default.fileExists(atPath: url.appendingPathComponent("model/fbank-80x201-f32.bin").path)
    }

    static func modelPackageRootCandidate(in url: URL) -> URL? {
        if isModelPackage(at: url) {
            return url
        }

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return contents.first { isModelPackage(at: $0) }
    }
}
