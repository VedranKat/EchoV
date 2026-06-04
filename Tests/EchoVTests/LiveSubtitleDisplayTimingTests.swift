import XCTest
@testable import EchoV

final class LiveSubtitleDisplayTimingTests: XCTestCase {
    func testLongSubtitleSplitsIntoReadableUnits() {
        let units = LiveSubtitleDisplayTiming.displayUnits(
            for: "When a speaker finishes a thought, the words should remain on screen long enough to understand them.",
            spokenDuration: 5.0,
            baseHoldSeconds: 2.2
        )

        XCTAssertGreaterThan(units.count, 1)
        XCTAssertTrue(units.allSatisfy { $0.text.split(separator: " ").count <= 12 })
        XCTAssertTrue(units.allSatisfy { $0.holdSeconds >= 2.2 })
        XCTAssertTrue(units.allSatisfy { $0.minimumReadableSeconds <= $0.holdSeconds })
    }

    func testSlowSpeechCanHoldLongerThanBaseSetting() {
        let unit = LiveSubtitleDisplayTiming.displayUnits(
            for: "The subtitle should breathe with the voice.",
            spokenDuration: 5.0,
            baseHoldSeconds: 2.2
        )[0]

        XCTAssertGreaterThan(unit.holdSeconds, 4.4)
    }

    func testReadableTextBeatsFixedHoldForDenseCaptions() {
        let unit = LiveSubtitleDisplayTiming.displayUnits(
            for: "A good result keeps almost every word and avoids empty space while the speaker is still talking.",
            spokenDuration: 2.0,
            baseHoldSeconds: 2.2
        )[0]

        XCTAssertGreaterThan(unit.holdSeconds, 2.2)
    }

    func testWhitespaceIsNormalized() {
        let units = LiveSubtitleDisplayTiming.displayUnits(
            for: "  Hello    there friend.\nThis   is clean now.  ",
            spokenDuration: 2.0,
            baseHoldSeconds: 1.0
        )

        XCTAssertEqual(units.map(\.text), ["Hello there friend.", "This is clean now."])
    }

    func testSyncPolicyKeepsTextVisibleWithoutBlockingNextCaption() {
        let unit = LiveSubtitleDisplayTiming.displayUnits(
            for: "This caption should not linger while newer captions are waiting.",
            spokenDuration: 4.0,
            baseHoldSeconds: 2.2
        )[0]

        let idleDwell = LiveSubtitleDisplaySyncPolicy.dwellSeconds(
            for: unit,
            hasBacklog: false,
            captionEndLagSeconds: 0
        )
        let backlogDwell = LiveSubtitleDisplaySyncPolicy.dwellSeconds(
            for: unit,
            hasBacklog: true,
            captionEndLagSeconds: 0
        )
        let staleDwell = LiveSubtitleDisplaySyncPolicy.dwellSeconds(
            for: unit,
            hasBacklog: true,
            captionEndLagSeconds: LiveSubtitleDisplaySyncPolicy.maximumCaptionEndLagSeconds + 1
        )

        XCTAssertLessThan(idleDwell, unit.holdSeconds)
        XCTAssertGreaterThanOrEqual(unit.holdSeconds, unit.minimumReadableSeconds)
        XCTAssertLessThanOrEqual(backlogDwell, idleDwell)
        XCTAssertLessThan(staleDwell, backlogDwell)
    }
}
