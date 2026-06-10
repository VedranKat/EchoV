import XCTest
@testable import EchoV

@MainActor
final class AssistantContextWindowLiveProviderTests: XCTestCase {
    func testTextRequestSentToProviderDropsOldTurnsBeforeCurrentTurn() async throws {
        let engine = try liveEngine()
        let largeOldText = String(repeating: "OLD_TEXT_DROP ", count: 900)
        let currentText = "CURRENT_TEXT_KEEP " + String(repeating: "fresh ", count: 20)
        let messages = [
            TextResponseMessage(role: .user, text: "old user 0 \(largeOldText)"),
            TextResponseMessage(role: .assistant, text: "old assistant 0 \(largeOldText)"),
            TextResponseMessage(role: .user, text: "old user 1 \(largeOldText)"),
            TextResponseMessage(role: .assistant, text: "old assistant 1 \(largeOldText)"),
            TextResponseMessage(role: .user, text: currentText)
        ]
        let request = TextResponseSessionPrompt(
            messages: messages,
            sessionKind: .text
        ).chatGenerationRequest(policy: .chat(stream: false, showReasoning: false))
        let configuration = AssistantContextWindowConfiguration(
            contextWindowTokens: 2_000,
            responseReserveTokens: request.maxTokens
        )
        let reduced = AssistantContextWindow.reduce(request, configuration: configuration)

        XCTAssertLessThanOrEqual(AssistantContextWindow.estimatedTokens(for: reduced.messages), configuration.inputBudgetTokens)
        XCTAssertFalse(reduced.messages.contains { $0.content.contains("OLD_TEXT_DROP") })
        XCTAssertTrue(reduced.messages.contains { $0.content.contains("CURRENT_TEXT_KEEP") })

        let result = try await engine.generate(request: reduced)
        XCTAssertEqual(result.content, "live ok")
    }

    func testVoiceRequestSentToProviderKeepsOnlyRecentConversationWindow() async throws {
        let engine = try liveEngine()
        var messages: [TextResponseMessage] = []
        for index in 0..<8 {
            messages.append(TextResponseMessage(role: .user, text: "VOICE_OLD_USER_\(index)"))
            messages.append(TextResponseMessage(role: .assistant, text: "VOICE_OLD_ASSISTANT_\(index)"))
        }
        for index in 0..<4 {
            messages.append(TextResponseMessage(role: .user, text: "VOICE_RECENT_USER_\(index)"))
            messages.append(TextResponseMessage(role: .assistant, text: "VOICE_RECENT_ASSISTANT_\(index)"))
        }
        messages.append(TextResponseMessage(role: .user, text: "VOICE_CURRENT_KEEP"))

        let request = TextResponseSessionPrompt(
            messages: messages,
            sessionKind: .voice
        ).chatGenerationRequest(policy: .finalAnswerOnly)
        let reduced = AssistantContextWindow.reduce(
            request,
            configuration: AssistantContextWindowConfiguration(
                contextWindowTokens: 128_000,
                responseReserveTokens: request.maxTokens,
                maximumRecentMessages: 10
            )
        )
        let conversationMessages = reduced.messages.filter { $0.role != .system }

        XCTAssertLessThanOrEqual(conversationMessages.count, 10)
        XCTAssertEqual(conversationMessages.first?.role, .user)
        XCTAssertFalse(reduced.messages.contains { $0.content.contains("VOICE_OLD_USER_0") })
        XCTAssertFalse(reduced.messages.contains { $0.content.contains("VOICE_OLD_ASSISTANT_7") })
        XCTAssertTrue(reduced.messages.contains { $0.content.contains("VOICE_RECENT_USER_0") })
        XCTAssertTrue(reduced.messages.contains { $0.content.contains("VOICE_CURRENT_KEEP") })

        let result = try await engine.generate(request: reduced)
        XCTAssertEqual(result.content, "live ok")
    }

    func testStreamingRequestSentToProviderTrimsHugeCurrentTurn() async throws {
        let engine = try liveEngine()
        let hugeCurrentText = "CURRENT_STREAM_KEEP " + String(repeating: "selected ", count: 4_000)
        let request = TextResponseSessionPrompt(
            messages: [TextResponseMessage(role: .user, text: hugeCurrentText)],
            sessionKind: .text
        ).chatGenerationRequest(policy: .chat(stream: true, showReasoning: true))
        let configuration = AssistantContextWindowConfiguration(
            contextWindowTokens: 2_000,
            responseReserveTokens: request.maxTokens
        )
        let reduced = AssistantContextWindow.reduce(request, configuration: configuration)

        XCTAssertLessThanOrEqual(AssistantContextWindow.estimatedTokens(for: reduced.messages), configuration.inputBudgetTokens)
        XCTAssertTrue(reduced.messages.last?.content.contains("CURRENT_STREAM_KEEP") == true)
        XCTAssertTrue(reduced.messages.last?.content.contains("Current message truncated by EchoV") == true)

        var events: [ChatGenerationEvent] = []
        let result = try await engine.stream(request: reduced) { event in
            events.append(event)
        }

        XCTAssertEqual(events, [.reasoningDelta("live thought "), .contentDelta("stream ok")])
        XCTAssertEqual(result.content, "stream ok")
        XCTAssertEqual(result.reasoning, "live thought")
    }

    private func liveEngine() throws -> OpenAICompatibleVoiceModeTextGenerationEngine {
        guard let baseURL = ProcessInfo.processInfo.environment["ECHOV_LIVE_OPENAI_COMPATIBLE_BASE_URL"],
              !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw XCTSkip("Set ECHOV_LIVE_OPENAI_COMPATIBLE_BASE_URL to run live provider-boundary tests.")
        }

        return OpenAICompatibleVoiceModeTextGenerationEngine(
            baseURL: { baseURL },
            model: { "live-window-model" },
            apiKey: { "live-window-key" },
            proxySettings: { .disabled }
        )
    }
}
