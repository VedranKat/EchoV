import XCTest
@testable import EchoV

final class SpeakerVerifierRuntimeLayoutTests: XCTestCase {
    func testDetectsCompleteRuntimeLayout() throws {
        let folder = try temporaryFolder()
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("model"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("lib"), withIntermediateDirectories: true)

        FileManager.default.createFile(atPath: folder.appendingPathComponent("manifest.json").path, contents: Data())
        FileManager.default.createFile(atPath: folder.appendingPathComponent("model/ecapa-speaker-v1.onnx").path, contents: Data())
        FileManager.default.createFile(atPath: folder.appendingPathComponent("model/fbank-80x201-f32.bin").path, contents: Data())
        FileManager.default.createFile(atPath: folder.appendingPathComponent("lib/libonnxruntime.dylib").path, contents: Data())

        let executableURL = folder.appendingPathComponent("bin/speaker-verifier")
        FileManager.default.createFile(atPath: executableURL.path, contents: Data())
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executableURL.path)

        XCTAssertEqual(SpeakerVerifierRuntimeLayout.missingFiles(at: folder), [])
        XCTAssertEqual(SpeakerVerifierRuntimeLayout.speakerVerifierCandidate(in: folder), executableURL)
        XCTAssertEqual(
            SpeakerVerifierRuntimeLayout.onnxRuntimeLibraryCandidate(in: folder)?.standardizedFileURL,
            folder.appendingPathComponent("lib/libonnxruntime.dylib").standardizedFileURL
        )
    }

    func testReportsMissingRuntimeFiles() throws {
        let folder = try temporaryFolder()

        XCTAssertEqual(
            SpeakerVerifierRuntimeLayout.missingFiles(at: folder),
            ["manifest.json", "model/ecapa-speaker-v1.onnx", "model/fbank-80x201-f32.bin", "bin/speaker-verifier", "lib/onnxruntime"]
        )
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
