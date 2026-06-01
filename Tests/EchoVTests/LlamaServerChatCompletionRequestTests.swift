import XCTest
@testable import EchoV

final class LlamaServerChatCompletionRequestTests: XCTestCase {
    func testFinalAnswerRequestsDisableLlamaThinking() throws {
        let request = LlamaServerChatCompletionRequest(
            chatRequest: LocalChatPrompt(system: "System", user: "User")
                .chatGenerationRequest(policy: .finalAnswerOnly),
            stream: false
        )

        let json = try encodedJSONObject(request)
        let kwargs = try XCTUnwrap(json["chat_template_kwargs"] as? [String: Any])
        XCTAssertEqual(kwargs["enable_thinking"] as? Bool, false)
    }

    func testHiddenReasoningIsDisabledWhenChatReasoningIsNotShown() throws {
        let request = LlamaServerChatCompletionRequest(
            chatRequest: ChatGenerationRequest(
                messages: [ChatGenerationMessage(role: .user, content: "Answer this")],
                temperature: 0.2,
                topP: 0.9,
                maxTokens: 512,
                policy: .chat(stream: false, showReasoning: false)
            ),
            stream: false
        )

        let json = try encodedJSONObject(request)
        let kwargs = try XCTUnwrap(json["chat_template_kwargs"] as? [String: Any])
        XCTAssertEqual(kwargs["enable_thinking"] as? Bool, false)
    }

    func testVisibleReasoningRequestsDoNotDisableLlamaThinking() throws {
        let request = LlamaServerChatCompletionRequest(
            chatRequest: ChatGenerationRequest(
                messages: [ChatGenerationMessage(role: .user, content: "Answer this")],
                temperature: 0.2,
                topP: 0.9,
                maxTokens: 512,
                policy: .chat(stream: true, showReasoning: true)
            ),
            stream: true
        )

        let json = try encodedJSONObject(request)
        XCTAssertNil(json["chat_template_kwargs"])
    }

    private func encodedJSONObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
