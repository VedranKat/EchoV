import XCTest
@testable import EchoV

final class AssistantContextWindowTests: XCTestCase {
    func testKeepsRecentMessagesUnderBudget() {
        let request = ChatGenerationRequest(
            messages: [
                ChatGenerationMessage(role: .system, content: "System"),
                ChatGenerationMessage(role: .user, content: "Old user"),
                ChatGenerationMessage(role: .assistant, content: "Old assistant"),
                ChatGenerationMessage(role: .user, content: "Recent user"),
                ChatGenerationMessage(role: .assistant, content: "Recent assistant"),
                ChatGenerationMessage(role: .user, content: "Current user")
            ],
            temperature: 0.3,
            topP: 0.9,
            maxTokens: 700,
            policy: .finalAnswerOnly
        )

        let reduced = AssistantContextWindow.reduce(
            request,
            configuration: AssistantContextWindowConfiguration(
                contextWindowTokens: 4_096,
                responseReserveTokens: 700,
                maximumRecentMessages: 3
            )
        )

        XCTAssertEqual(reduced.messages.map(\.role), [.system, .user, .assistant, .user])
        XCTAssertEqual(reduced.messages.map(\.content), ["System", "Recent user", "Recent assistant", "Current user"])
    }

    func testDropsOldestMessagesUntilUnderBudget() {
        let largeOldText = String(repeating: "old ", count: 2_000)
        let request = ChatGenerationRequest(
            messages: [
                ChatGenerationMessage(role: .system, content: "System"),
                ChatGenerationMessage(role: .user, content: largeOldText),
                ChatGenerationMessage(role: .assistant, content: largeOldText),
                ChatGenerationMessage(role: .user, content: "Current user")
            ],
            temperature: 0.3,
            topP: 0.9,
            maxTokens: 700,
            policy: .finalAnswerOnly
        )

        let reduced = AssistantContextWindow.reduce(
            request,
            configuration: AssistantContextWindowConfiguration(
                contextWindowTokens: 2_000,
                responseReserveTokens: 700
            )
        )

        XCTAssertEqual(reduced.messages.map(\.content), ["System", "Current user"])
        XCTAssertLessThanOrEqual(
            AssistantContextWindow.estimatedTokens(for: reduced.messages),
            AssistantContextWindowConfiguration(contextWindowTokens: 2_000, responseReserveTokens: 700).inputBudgetTokens
        )
    }

    func testTrimsCurrentMessageWhenItAloneExceedsBudget() {
        let hugeCurrentText = String(repeating: "selected ", count: 4_000)
        let request = ChatGenerationRequest(
            messages: [
                ChatGenerationMessage(role: .system, content: "System"),
                ChatGenerationMessage(role: .user, content: hugeCurrentText)
            ],
            temperature: 0.3,
            topP: 0.9,
            maxTokens: 700,
            policy: .finalAnswerOnly
        )

        let reduced = AssistantContextWindow.reduce(
            request,
            configuration: AssistantContextWindowConfiguration(
                contextWindowTokens: 2_000,
                responseReserveTokens: 700
            )
        )

        XCTAssertEqual(reduced.messages.count, 2)
        XCTAssertTrue(reduced.messages[1].content.contains("Current message truncated by EchoV"))
        XCTAssertLessThan(reduced.messages[1].content.count, hugeCurrentText.count)
        XCTAssertLessThanOrEqual(
            AssistantContextWindow.estimatedTokens(for: reduced.messages),
            AssistantContextWindowConfiguration(contextWindowTokens: 2_000, responseReserveTokens: 700).inputBudgetTokens
        )
    }
}
