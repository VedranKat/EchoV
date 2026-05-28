import XCTest
@testable import EchoV

final class WakePhraseMatcherTests: XCTestCase {
    func testAcceptsIsolatedVoiceAndTextActivationCommandsWithPunctuation() {
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "Computer."), .spoken)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "  computer!  "), .spoken)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "Slate."), .textResponse)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "  slate!  "), .textResponse)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "Continue."), .continueTextResponse)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "  continue!  "), .continueTextResponse)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "Prime cleanup."), .cleanUpSelection)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "  prime, clean up!  "), .cleanUpSelection)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "prime clean-up"), .cleanUpSelection)
    }

    func testRejectsActivationCommandsInsideLongerPhrases() {
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "hey computer"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer what time is it"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer computer"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "open slate"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "slate summarize this"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "continue please"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "slate continue"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer continue"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "prime clean this up"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "prime cleanup please"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "please prime cleanup"))
    }

    func testRejectsSimilarButDifferentTranscripts() {
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "commuter"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "compute her"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "plate"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: ""))
    }

}
