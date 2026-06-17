import XCTest
@testable import EchoV

final class VoiceModeEditPromptTests: XCTestCase {
    func testBuildsReplacementOnlyEditRequest() {
        let request = VoiceModeEditPrompt(
            selectedText: "This is too long and unfocused.",
            instruction: "Make it shorter."
        ).chatGenerationRequest()

        XCTAssertEqual(request.policy, .finalAnswerOnly)
        XCTAssertEqual(request.temperature, 0.2)
        XCTAssertEqual(request.messages.count, 2)
        XCTAssertEqual(request.messages[0].role, .system)
        XCTAssertTrue(request.messages[0].content.contains("Return only the edited replacement text."))
        XCTAssertEqual(request.messages[1].role, .user)
        XCTAssertTrue(request.messages[1].content.contains("Instruction:\nMake it shorter."))
        XCTAssertTrue(request.messages[1].content.contains("Selected text:\nThis is too long and unfocused."))
    }
}
