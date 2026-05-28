import XCTest
@testable import EchoV

final class VoiceModePromptTests: XCTestCase {
    func testPromptUsesSpokenRequestAsUserMessage() {
        let prompt = VoiceModePrompt(userText: "summarize my next meeting").chatPrompt

        XCTAssertEqual(prompt.user, "summarize my next meeting")
    }

    func testPromptRequestsConciseVoiceFirstAnswers() {
        let prompt = VoiceModePrompt(userText: "what should I do next").chatPrompt

        XCTAssertTrue(prompt.system.contains("voice-first assistant"))
        XCTAssertTrue(prompt.system.contains("Keep responses concise"))
        XCTAssertEqual(prompt.maxTokens, 700)
        XCTAssertEqual(prompt.temperature, 0.35)
    }
}
