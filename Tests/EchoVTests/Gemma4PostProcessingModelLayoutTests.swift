import XCTest
@testable import EchoV

final class Gemma4PostProcessingModelLayoutTests: XCTestCase {
    func testFindsPreferredGGUFInSelectedFolder() throws {
        let folder = try temporaryFolder()
        let modelURL = folder.appendingPathComponent(Gemma4PostProcessingModelLayout.ggufFileName)
        FileManager.default.createFile(atPath: modelURL.path, contents: Data())

        assertSameURL(Gemma4PostProcessingModelLayout.ggufModelFileCandidate(for: folder), modelURL)
    }

    func testAcceptsDirectGGUFSelection() throws {
        let folder = try temporaryFolder()
        let modelURL = folder.appendingPathComponent("custom.gguf")
        FileManager.default.createFile(atPath: modelURL.path, contents: Data())

        assertSameURL(Gemma4PostProcessingModelLayout.ggufModelFileCandidate(for: modelURL), modelURL)
    }

    func testFindsPreferredE4BGGUFInSelectedFolder() throws {
        let definition = PostProcessingModelDefinition.gemma4E4B
        let folder = try temporaryFolder()
        let modelURL = folder.appendingPathComponent(definition.ggufFileName)
        FileManager.default.createFile(atPath: modelURL.path, contents: Data())

        assertSameURL(
            Gemma4PostProcessingModelLayout.ggufModelFileCandidate(for: folder, definition: definition),
            modelURL
        )
    }

    func testFindsSelectedDefinitionInParentFolder() throws {
        let definition = PostProcessingModelDefinition.gemma4E4B
        let parent = try temporaryFolder()
        let modelFolder = parent.appendingPathComponent(definition.expectedFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: modelFolder, withIntermediateDirectories: true)
        let modelURL = modelFolder.appendingPathComponent(definition.ggufFileName)
        FileManager.default.createFile(atPath: modelURL.path, contents: Data())

        assertSameURL(
            Gemma4PostProcessingModelLayout.modelFolderCandidate(for: parent, definition: definition),
            modelFolder
        )
        assertSameURL(
            Gemma4PostProcessingModelLayout.ggufModelFileCandidate(for: parent, definition: definition),
            modelURL
        )
    }

    func testFallsBackToAnyGGUFWhenPreferredFileIsMissing() throws {
        let definition = PostProcessingModelDefinition.gemma4E4B
        let folder = try temporaryFolder()
        let modelURL = folder.appendingPathComponent("custom-\(definition.id).gguf")
        FileManager.default.createFile(atPath: modelURL.path, contents: Data())

        assertSameURL(
            Gemma4PostProcessingModelLayout.ggufModelFileCandidate(for: folder, definition: definition),
            modelURL
        )
    }

    func testRecognizesManagedModelDefinitionsSeparately() {
        XCTAssertEqual(
            Gemma4PostProcessingModelLayout.managedModelDefinition(
                for: Gemma4PostProcessingModelLayout.managedModelURL(for: .gemma4E2B)
            ),
            .gemma4E2B
        )
        XCTAssertEqual(
            Gemma4PostProcessingModelLayout.managedModelDefinition(
                for: Gemma4PostProcessingModelLayout.managedModelURL(for: .gemma4E4B)
            ),
            .gemma4E4B
        )
    }

    func testDefaultModelRemainsE2BForExistingInstalls() {
        XCTAssertEqual(PostProcessingModelDefinition.defaultModel, .gemma4E2B)
        XCTAssertEqual(Gemma4PostProcessingModelLayout.expectedFolderName, "gemma-4-E2B-it")
        XCTAssertEqual(Gemma4PostProcessingModelLayout.ggufFileName, "gemma-4-E2B-it-Q4_K_M.gguf")
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

    private func assertSameURL(
        _ actual: URL?,
        _ expected: URL,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            actual?.resolvingSymlinksInPath(),
            expected.resolvingSymlinksInPath(),
            file: file,
            line: line
        )
    }
}
