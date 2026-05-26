import CryptoKit
import XCTest
@testable import EchoV

final class SpeakerVerifierRuntimeInstallerTests: XCTestCase {
    func testInstallsLocalModelFilesIntoManagedRuntimeDirectory() async throws {
        let root = try temporaryFolder()
        let modelSource = root.appendingPathComponent("source", isDirectory: true)
        let supportRuntime = root.appendingPathComponent("support", isDirectory: true)
        let managedRuntime = root.appendingPathComponent("managed/speaker-verifier", isDirectory: true)

        try FileManager.default.createDirectory(at: modelSource.appendingPathComponent("model"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: supportRuntime.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: supportRuntime.appendingPathComponent("lib"), withIntermediateDirectories: true)

        let manifestURL = modelSource.appendingPathComponent("manifest.json")
        let modelURL = modelSource.appendingPathComponent("model/ecapa-speaker-v1.onnx")
        let fbankURL = modelSource.appendingPathComponent("model/fbank-80x201-f32.bin")
        let manifestData = Data(#"{"schema_version":1}"#.utf8)
        let modelData = Data("onnx-model".utf8)
        let fbankData = Data("fbank-table".utf8)
        try manifestData.write(to: manifestURL)
        try modelData.write(to: modelURL)
        try fbankData.write(to: fbankURL)
        FileManager.default.createFile(atPath: supportRuntime.appendingPathComponent("lib/libonnxruntime.dylib").path, contents: Data())

        let executable = supportRuntime.appendingPathComponent("bin/speaker-verifier")
        FileManager.default.createFile(atPath: executable.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        setenv("ECHOV_SPEAKER_VERIFIER_MODEL_BASE_URL", modelSource.absoluteString, 1)
        setenv("ECHOV_SPEAKER_VERIFIER_MANIFEST_SHA256", sha256(of: manifestData), 1)
        setenv("ECHOV_SPEAKER_VERIFIER_ONNX_SHA256", sha256(of: modelData), 1)
        setenv("ECHOV_SPEAKER_VERIFIER_FBANK_SHA256", sha256(of: fbankData), 1)
        setenv("ECHOV_SPEAKER_VERIFIER_RUNTIME_DIR", managedRuntime.path, 1)
        setenv("ECHOV_SPEAKER_VERIFIER_SUPPORT_DIR", supportRuntime.path, 1)
        defer {
            unsetenv("ECHOV_SPEAKER_VERIFIER_MODEL_BASE_URL")
            unsetenv("ECHOV_SPEAKER_VERIFIER_MANIFEST_SHA256")
            unsetenv("ECHOV_SPEAKER_VERIFIER_ONNX_SHA256")
            unsetenv("ECHOV_SPEAKER_VERIFIER_FBANK_SHA256")
            unsetenv("ECHOV_SPEAKER_VERIFIER_RUNTIME_DIR")
            unsetenv("ECHOV_SPEAKER_VERIFIER_SUPPORT_DIR")
        }

        let installedURL = try await SpeakerVerifierRuntimeInstaller().install(proxySettings: .disabled) { _ in }

        XCTAssertEqual(installedURL.standardizedFileURL, managedRuntime.standardizedFileURL)
        XCTAssertTrue(SpeakerVerifierRuntimeLayout.isInstalled())
        XCTAssertTrue(FileManager.default.fileExists(atPath: managedRuntime.appendingPathComponent("model/ecapa-speaker-v1.onnx").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedRuntime.appendingPathComponent("bin/speaker-verifier").path))
    }

    private func sha256(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: folder)
        }
        return folder
    }
}
