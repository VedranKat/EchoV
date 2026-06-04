import XCTest
@testable import EchoV

@MainActor
final class LiveSubtitleStoreTests: XCTestCase {
    func testNewSubtitleAddsVisibleRowWithoutKeepingStalePreviousLine() {
        let store = LiveSubtitleStore()

        let firstChunkID = UUID()
        let secondChunkID = UUID()
        store.showSubtitle("first line", chunkID: firstChunkID, isFinal: true)
        store.showSubtitle("second line", chunkID: secondChunkID, isFinal: true)

        XCTAssertEqual(store.currentText, "second line")
        XCTAssertEqual(store.previousText, "")
        XCTAssertEqual(store.visibleLines.map(\.text), ["first line", "second line"])
        XCTAssertTrue(store.hasVisibleSubtitle)
    }

    func testSameLineUpdateReplacesVisibleRow() {
        let store = LiveSubtitleStore()
        let chunkID = UUID()
        let lineID = LiveSubtitleLineID(chunkID: chunkID, unitIndex: 0)

        store.showSubtitle("raw line", chunkID: chunkID, lineID: lineID, isFinal: false)
        store.showSubtitle("final line", chunkID: chunkID, lineID: lineID, isFinal: true)

        XCTAssertEqual(store.visibleLines.map(\.text), ["final line"])
        XCTAssertTrue(store.visibleLines[0].isFinal)
    }

    func testFinalSubtitleRemovesOtherRawRowsForSameChunk() {
        let store = LiveSubtitleStore()
        let chunkID = UUID()

        store.showSubtitle(
            "raw line one",
            chunkID: chunkID,
            lineID: LiveSubtitleLineID(chunkID: chunkID, unitIndex: 0),
            isFinal: false
        )
        store.showSubtitle(
            "raw line two",
            chunkID: chunkID,
            lineID: LiveSubtitleLineID(chunkID: chunkID, unitIndex: 1),
            isFinal: false
        )
        store.showSubtitle(
            "final line one",
            chunkID: chunkID,
            lineID: LiveSubtitleLineID(chunkID: chunkID, unitIndex: 0),
            isFinal: true
        )

        XCTAssertEqual(store.visibleLines.map(\.text), ["final line one"])
    }

    func testVisibleRowsAreCappedToOverlayMaximum() {
        let store = LiveSubtitleStore()

        for index in 0..<4 {
            store.showSubtitle("line \(index)", chunkID: UUID(), isFinal: true)
        }

        XCTAssertEqual(store.visibleLines.map(\.text), ["line 1", "line 2", "line 3"])
    }
}
