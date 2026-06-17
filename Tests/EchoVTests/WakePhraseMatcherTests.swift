import XCTest
@testable import EchoV

final class WakePhraseMatcherTests: XCTestCase {
    func testAcceptsIsolatedVoiceAndTextActivationCommandsWithPunctuation() {
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "Computer."), .spoken)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "  computer!  "), .spoken)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "Computer text."), .textResponse)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "  computer, text!  "), .textResponse)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "Continue."), .continueTextResponse)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "  continue!  "), .continueTextResponse)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "Computer refresh."), .refreshSession)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "  computer, refresh!  "), .refreshSession)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "Computer cleanup."), .cleanUpSelection)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "  computer, clean up!  "), .cleanUpSelection)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "computer clean-up"), .cleanUpSelection)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "Computer edit."), .editSelection)
        XCTAssertEqual(WakePhraseMatcher.activationCommand(for: "  computer, edit!  "), .editSelection)
    }

    func testRejectsActivationCommandsInsideLongerPhrases() {
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "hey computer"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer what time is it"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer computer"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "open computer text"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer text summarize this"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "continue please"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer text continue"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer continue"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer refresh please"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "please computer refresh"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer new"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer clean this up"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer cleanup please"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "please computer cleanup"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer edit this"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "computer edit please"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "please computer edit"))
    }

    func testRejectsSimilarButDifferentTranscripts() {
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "commuter"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "compute her"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: "plate"))
        XCTAssertNil(WakePhraseMatcher.activationCommand(for: ""))
    }

}
