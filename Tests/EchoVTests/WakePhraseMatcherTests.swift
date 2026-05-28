import XCTest
@testable import EchoV

final class WakePhraseMatcherTests: XCTestCase {
    func testAcceptsIsolatedComputerWithPunctuation() {
        XCTAssertTrue(WakePhraseMatcher.isActivationPhrase("Computer."))
        XCTAssertTrue(WakePhraseMatcher.isActivationPhrase("  computer!  "))
    }

    func testRejectsComputerInsideLongerPhrase() {
        XCTAssertFalse(WakePhraseMatcher.isActivationPhrase("hey computer"))
        XCTAssertFalse(WakePhraseMatcher.isActivationPhrase("computer what time is it"))
        XCTAssertFalse(WakePhraseMatcher.isActivationPhrase("computer computer"))
    }

    func testRejectsSimilarButDifferentTranscripts() {
        XCTAssertFalse(WakePhraseMatcher.isActivationPhrase("commuter"))
        XCTAssertFalse(WakePhraseMatcher.isActivationPhrase("compute her"))
        XCTAssertFalse(WakePhraseMatcher.isActivationPhrase(""))
    }
}
