import XCTest
@testable import EchoV

final class TextResponseSessionTests: XCTestCase {
    @MainActor
    func testStartsSessionWithInitialExchangeAndShortTitle() {
        let store = TextResponseSessionStore()

        let sessionID = store.startSession(
            userText: "Explain notification summaries",
            responseText: "They appear as a macOS notification."
        )

        XCTAssertEqual(store.selectedSessionID, sessionID)
        XCTAssertEqual(store.activeSessionID, sessionID)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.selectedSession?.kind, .text)
        XCTAssertEqual(store.selectedSession?.title, "Explain notification summaries")
        XCTAssertEqual(store.messages(for: sessionID).map(\.role), [.user, .assistant])
        XCTAssertFalse(store.isGenerating(sessionID: sessionID))
    }

    @MainActor
    func testStartsEmptyVoiceSessionAndMarksItActive() {
        let store = TextResponseSessionStore()

        let sessionID = store.startSession(kind: .voice, titleSeed: "  Summarize this selection  ")

        XCTAssertEqual(store.selectedSessionID, sessionID)
        XCTAssertEqual(store.activeSessionID, sessionID)
        XCTAssertEqual(store.selectedSession?.kind, .voice)
        XCTAssertEqual(store.selectedSession?.title, "Summarize this selection")
        XCTAssertEqual(store.messages(for: sessionID), [])
    }

    @MainActor
    func testSelectingOlderSessionMakesItActive() {
        let store = TextResponseSessionStore()
        let firstID = store.startSession(userText: "First", responseText: "One")
        let secondID = store.startSession(userText: "Second", responseText: "Two")

        XCTAssertEqual(store.activeSessionID, secondID)

        store.select(firstID)

        XCTAssertEqual(store.selectedSessionID, firstID)
        XCTAssertEqual(store.activeSessionID, firstID)
    }

    @MainActor
    func testAppendingUserMessageMarksSessionActive() {
        let store = TextResponseSessionStore()
        let firstID = store.startSession(userText: "First", responseText: "One")
        let secondID = store.startSession(userText: "Second", responseText: "Two")

        store.appendUserMessage(sessionID: firstID, text: "Back to the first thread")

        XCTAssertEqual(store.activeSessionID, firstID)
        XCTAssertEqual(store.selectedSessionID, secondID)
    }

    @MainActor
    func testStreamsAssistantMessageContentAndReasoning() {
        let store = TextResponseSessionStore()
        let sessionID = store.startSession(userText: "Start", responseText: "Initial")
        store.appendUserMessage(sessionID: sessionID, text: "Continue")

        let messageID = store.startAssistantStreamingMessage(sessionID: sessionID)

        XCTAssertNotNil(messageID)
        XCTAssertTrue(store.isGenerating(sessionID: sessionID))

        guard let messageID else {
            XCTFail("Expected a streaming message ID")
            return
        }

        store.appendAssistantReasoningDelta(sessionID: sessionID, messageID: messageID, delta: "Hidden ")
        store.appendAssistantReasoningDelta(sessionID: sessionID, messageID: messageID, delta: "reasoning")
        store.appendAssistantContentDelta(sessionID: sessionID, messageID: messageID, delta: "Visible ")
        store.appendAssistantContentDelta(sessionID: sessionID, messageID: messageID, delta: "answer")

        let streamingMessage = store.messages(for: sessionID).last
        XCTAssertEqual(streamingMessage?.reasoning, "Hidden reasoning")
        XCTAssertEqual(streamingMessage?.text, "Visible answer")
        XCTAssertTrue(streamingMessage?.isStreaming == true)

        store.finishAssistantStreamingMessage(
            sessionID: sessionID,
            messageID: messageID,
            finalContent: "Visible answer",
            finalReasoning: "Hidden reasoning"
        )

        let finishedMessage = store.messages(for: sessionID).last
        XCTAssertFalse(store.isGenerating(sessionID: sessionID))
        XCTAssertEqual(finishedMessage?.text, "Visible answer")
        XCTAssertEqual(finishedMessage?.reasoning, "Hidden reasoning")
        XCTAssertFalse(finishedMessage?.isStreaming == true)
    }

    func testPromptIncludesFullSessionTranscript() {
        let prompt = TextResponseSessionPrompt(messages: [
            TextResponseMessage(role: .user, text: "What did I ask?"),
            TextResponseMessage(role: .assistant, text: "You asked for a text response mode."),
            TextResponseMessage(role: .user, text: "Continue that thread.")
        ]).chatPrompt

        XCTAssertTrue(prompt.system.contains("EchoV Text Response Mode"))
        XCTAssertEqual(
            prompt.user,
            """
            User: What did I ask?

            Assistant: You asked for a text response mode.

            User: Continue that thread.
            """
        )
        XCTAssertEqual(prompt.maxTokens, 768)
        XCTAssertEqual(prompt.temperature, 0.3)
    }

    func testChatGenerationRequestUsesMessageRolesAndFinalOnlyInstruction() {
        let request = TextResponseSessionPrompt(messages: [
            TextResponseMessage(role: .user, text: "What did I ask?"),
            TextResponseMessage(role: .assistant, text: "You asked for a text response mode."),
            TextResponseMessage(role: .user, text: "Continue that thread.")
        ]).chatGenerationRequest(policy: .finalAnswerOnly)

        XCTAssertEqual(request.policy, .finalAnswerOnly)
        XCTAssertEqual(request.messages.map(\.role), [.system, .user, .assistant, .user])
        XCTAssertTrue(request.messages[0].content.contains("Do not include hidden reasoning"))
    }

    func testChatGenerationRequestAllowsReasoningInstructionWhenEnabled() {
        let request = TextResponseSessionPrompt(messages: [
            TextResponseMessage(role: .user, text: "Continue")
        ]).chatGenerationRequest(policy: .chat(stream: true, showReasoning: true))

        XCTAssertEqual(request.policy, .chat(stream: true, showReasoning: true))
        XCTAssertFalse(request.messages[0].content.contains("Do not include hidden reasoning"))
    }

    func testVoiceSessionPromptUsesVoiceFirstSettings() {
        let prompt = TextResponseSessionPrompt(
            messages: [
                TextResponseMessage(role: .user, text: "Summarize this")
            ],
            sessionKind: .voice
        ).chatPrompt

        XCTAssertTrue(prompt.system.contains("voice-first assistant"))
        XCTAssertTrue(prompt.system.contains("copied webpage"))
        XCTAssertEqual(prompt.maxTokens, 700)
        XCTAssertEqual(prompt.temperature, 0.35)
    }
}
