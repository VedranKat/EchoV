import Foundation

enum LlamaRuntimeLayout {
    static let version = "b9060"
    static let displayName = "llama.cpp \(version)"
    static let archiveFileName = "llama-\(version)-bin-macos-arm64.tar.gz"
    static let expectedSHA256 = "dd89c0428d99fbcdbe39406cbfce56e2d5fb1b46d93047055ba576ea6d12fbaa"
    static let downloadURL = URL(
        string: "https://github.com/ggml-org/llama.cpp/releases/download/\(version)/\(archiveFileName)"
    )!

    static var managedRuntimeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EchoV/Runtimes/llama.cpp", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
    }

    static var managedExecutableURL: URL? {
        llamaServerCandidate(in: managedRuntimeURL)
    }

    static func isInstalled() -> Bool {
        managedExecutableURL != nil
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    static func llamaServerCandidate(in url: URL) -> URL? {
        let directURL = url.appendingPathComponent("llama-server")
        if FileManager.default.isExecutableFile(atPath: directURL.path) {
            return directURL
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return nil
        }

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "llama-server" {
            if FileManager.default.isExecutableFile(atPath: fileURL.path) {
                return fileURL
            }
        }

        return nil
    }
}
