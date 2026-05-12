import XCTest
@testable import EchoV

final class Gemma4PostProcessingModelLayoutTests: XCTestCase {
    func testFindsPreferredGGUFInSelectedFolder() throws {
        let folder = try temporaryFolder()
        let modelURL = folder.appendingPathComponent(Gemma4PostProcessingModelLayout.ggufFileName)
        FileManager.default.createFile(atPath: modelURL.path, contents: Data())

        XCTAssertEqual(Gemma4PostProcessingModelLayout.ggufModelFileCandidate(for: folder), modelURL)
    }

    func testAcceptsDirectGGUFSelection() throws {
        let folder = try temporaryFolder()
        let modelURL = folder.appendingPathComponent("custom.gguf")
        FileManager.default.createFile(atPath: modelURL.path, contents: Data())

        XCTAssertEqual(Gemma4PostProcessingModelLayout.ggufModelFileCandidate(for: modelURL), modelURL)
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
