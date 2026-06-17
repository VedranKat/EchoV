import XCTest
@testable import EchoV

final class VoiceModeAssistantRoutingTests: XCTestCase {
    @MainActor
    func testComputerTextStartsFreshTextSessionEvenWhenTextSessionIsActive() async {
        let container = AppContainer.bootstrap()
        let existingSessionID = container.textResponseSessions.startSession(kind: .text, titleSeed: "Existing text")

        await ignoreGenerationFailure {
            try await container.performVoiceModeAssistantTurn(command: .textResponse, userText: "Fresh text request")
        }

        let textSessions = container.textResponseSessions.sessions.filter { $0.kind == .text }
        XCTAssertEqual(textSessions.count, 2)
        XCTAssertNotEqual(container.textResponseSessions.activeSessionID, existingSessionID)
        XCTAssertEqual(container.textResponseSessions.activeSession?.kind, .text)
        XCTAssertEqual(container.textResponseSessions.activeSession?.messages.first?.text, "Fresh text request")
    }

    @MainActor
    func testComputerTextStartsFreshTextSessionWhenActiveTextSessionIsGenerating() async {
        let container = AppContainer.bootstrap()
        let existingSessionID = container.textResponseSessions.startSession(kind: .text, titleSeed: "Still thinking")
        container.textResponseSessions.setGenerating(true, sessionID: existingSessionID)

        await ignoreGenerationFailure {
            try await container.performVoiceModeAssistantTurn(command: .textResponse, userText: "Separate text request")
        }

        XCTAssertEqual(container.textResponseSessions.sessions.filter { $0.kind == .text }.count, 2)
        XCTAssertNotEqual(container.textResponseSessions.activeSessionID, existingSessionID)
        XCTAssertEqual(container.textResponseSessions.activeSession?.messages.first?.text, "Separate text request")
    }

    @MainActor
    func testComputerContinuesActiveVoiceSession() async {
        let container = AppContainer.bootstrap()
        let sessionID = container.textResponseSessions.startSession(kind: .voice, titleSeed: "Voice thread")

        await ignoreGenerationFailure {
            try await container.performVoiceModeAssistantTurn(command: .spoken, userText: "Follow up by voice")
        }

        XCTAssertEqual(container.textResponseSessions.sessions.filter { $0.kind == .voice }.count, 1)
        XCTAssertEqual(container.textResponseSessions.activeSessionID, sessionID)
        XCTAssertEqual(container.textResponseSessions.messages(for: sessionID).first?.text, "Follow up by voice")
    }

    @MainActor
    func testComputerRefreshStartsFreshVoiceSession() async {
        let container = AppContainer.bootstrap()
        let existingSessionID = container.textResponseSessions.startSession(kind: .voice, titleSeed: "Existing voice")

        await ignoreGenerationFailure {
            try await container.performVoiceModeAssistantTurn(command: .refreshSession, userText: "Fresh voice request")
        }

        XCTAssertEqual(container.textResponseSessions.sessions.filter { $0.kind == .voice }.count, 2)
        XCTAssertNotEqual(container.textResponseSessions.activeSessionID, existingSessionID)
        XCTAssertEqual(container.textResponseSessions.activeSession?.kind, .voice)
        XCTAssertEqual(container.textResponseSessions.activeSession?.messages.first?.text, "Fresh voice request")
    }

    @MainActor
    func testContinueFollowsActiveTextSession() async {
        let container = AppContainer.bootstrap()
        let sessionID = container.textResponseSessions.startSession(kind: .text, titleSeed: "Text thread")

        await ignoreGenerationFailure {
            try await container.performVoiceModeAssistantTurn(command: .continueTextResponse, userText: "Follow up in text")
        }

        XCTAssertEqual(container.textResponseSessions.sessions.filter { $0.kind == .text }.count, 1)
        XCTAssertEqual(container.textResponseSessions.activeSessionID, sessionID)
        XCTAssertEqual(container.textResponseSessions.messages(for: sessionID).first?.text, "Follow up in text")
    }

    @MainActor
    func testContinueWithoutActiveSessionFallsBackToVoiceSession() async {
        let container = AppContainer.bootstrap()

        await ignoreGenerationFailure {
            try await container.performVoiceModeAssistantTurn(command: .continueTextResponse, userText: "No previous chat")
        }

        XCTAssertEqual(container.textResponseSessions.sessions.count, 1)
        XCTAssertEqual(container.textResponseSessions.activeSession?.kind, .voice)
        XCTAssertEqual(container.textResponseSessions.activeSession?.messages.first?.text, "No previous chat")
    }

    @MainActor
    func testComputerEditRequiresSelectedText() async {
        let container = AppContainer.bootstrap()

        do {
            _ = try await container.performVoiceModeAssistantTurn(command: .editSelection, userText: "Make it shorter")
            XCTFail("Computer edit should require selected text.")
        } catch AppError.voiceModeResponseFailed(let details) {
            XCTAssertEqual(details, "No selected text is available to edit.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(container.textResponseSessions.sessions.isEmpty)
    }

    @MainActor
    func testComputerEditDoesNotCreateAssistantSessionBeforeGeneration() async {
        let container = AppContainer.bootstrap()

        await ignoreGenerationFailure {
            try await container.performVoiceModeAssistantTurn(
                command: .editSelection,
                userText: "Make it shorter",
                selectedText: "This is selected text that should be rewritten."
            )
        }

        XCTAssertTrue(container.textResponseSessions.sessions.isEmpty)
    }

    @MainActor
    private func ignoreGenerationFailure(_ operation: () async throws -> VoiceModeAssistantTurnResult) async {
        do {
            _ = try await operation()
        } catch {
            // Routing happens before generation; these tests intentionally use the unconfigured local model.
        }
    }
}
