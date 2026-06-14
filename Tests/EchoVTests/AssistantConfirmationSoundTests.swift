import XCTest
@testable import EchoV

final class AssistantConfirmationSoundTests: XCTestCase {
    func testLoadsKnownAndUnknownStyles() {
        XCTAssertEqual(AssistantConfirmationSoundStyle.load(from: "computer"), .computer)
        XCTAssertEqual(AssistantConfirmationSoundStyle.load(from: "unknown"), .starship)
        XCTAssertEqual(AssistantConfirmationSoundStyle.load(from: nil), .starship)
    }

    func testMapsCommandsToConfirmationCues() {
        XCTAssertEqual(AssistantConfirmationCue.cue(for: .spoken, activeSessionKind: nil), .voiceReady)
        XCTAssertEqual(AssistantConfirmationCue.cue(for: .refreshSession, activeSessionKind: nil), .voiceRefresh)
        XCTAssertEqual(AssistantConfirmationCue.cue(for: .textResponse, activeSessionKind: .voice), .textReady)
        XCTAssertEqual(AssistantConfirmationCue.cue(for: .cleanUpSelection, activeSessionKind: .text), .actionAccepted)
    }

    func testContinueCueFollowsActiveSessionKind() {
        XCTAssertEqual(AssistantConfirmationCue.cue(for: .continueTextResponse, activeSessionKind: .text), .textReady)
        XCTAssertEqual(AssistantConfirmationCue.cue(for: .continueTextResponse, activeSessionKind: .voice), .voiceReady)
        XCTAssertEqual(AssistantConfirmationCue.cue(for: .continueTextResponse, activeSessionKind: nil), .voiceReady)
    }
}
