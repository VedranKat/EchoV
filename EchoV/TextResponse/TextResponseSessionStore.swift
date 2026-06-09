import Foundation
import Observation

enum TextResponseMessageRole: String, Sendable {
    case user
    case assistant
}

enum TextResponseSessionKind: String, Sendable {
    case text
    case voice
}

struct TextResponseMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: TextResponseMessageRole
    var text: String
    var reasoning: String
    var isStreaming: Bool
    var streamError: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: TextResponseMessageRole,
        text: String,
        reasoning: String = "",
        isStreaming: Bool = false,
        streamError: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.reasoning = reasoning
        self.isStreaming = isStreaming
        self.streamError = streamError
        self.createdAt = createdAt
    }
}

struct TextResponseSession: Identifiable, Equatable, Sendable {
    let id: UUID
    var kind: TextResponseSessionKind
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [TextResponseMessage]
    var isGenerating: Bool
    var lastError: String?
}

@MainActor
@Observable
final class TextResponseSessionStore {
    var sessions: [TextResponseSession] = []
    var selectedSessionID: UUID? {
        didSet {
            guard let selectedSessionID,
                  sessions.contains(where: { $0.id == selectedSessionID })
            else {
                return
            }

            activeSessionID = selectedSessionID
        }
    }
    var activeSessionID: UUID?

    var selectedSession: TextResponseSession? {
        guard let selectedSessionID else {
            return sessions.first
        }

        return sessions.first { $0.id == selectedSessionID } ?? sessions.first
    }

    var activeSession: TextResponseSession? {
        guard let activeSessionID else {
            return nil
        }

        return sessions.first { $0.id == activeSessionID }
    }

    func startSession(
        kind: TextResponseSessionKind = .text,
        userText: String,
        responseText: String
    ) -> UUID {
        let id = UUID()
        let now = Date()
        let title = Self.sessionTitle(from: userText, fallback: Self.fallbackTitle(for: kind))
        let session = TextResponseSession(
            id: id,
            kind: kind,
            title: title,
            createdAt: now,
            updatedAt: now,
            messages: [
                TextResponseMessage(role: .user, text: userText, createdAt: now),
                TextResponseMessage(role: .assistant, text: responseText, createdAt: now)
            ],
            isGenerating: false,
            lastError: nil
        )

        sessions.insert(session, at: 0)
        selectedSessionID = id
        activeSessionID = id
        return id
    }

    func startSession(kind: TextResponseSessionKind, titleSeed: String) -> UUID {
        let id = UUID()
        let now = Date()
        let session = TextResponseSession(
            id: id,
            kind: kind,
            title: Self.sessionTitle(from: titleSeed, fallback: Self.fallbackTitle(for: kind)),
            createdAt: now,
            updatedAt: now,
            messages: [],
            isGenerating: false,
            lastError: nil
        )

        sessions.insert(session, at: 0)
        selectedSessionID = id
        activeSessionID = id
        return id
    }

    func select(_ sessionID: UUID) {
        guard sessions.contains(where: { $0.id == sessionID }) else {
            return
        }

        selectedSessionID = sessionID
        activeSessionID = sessionID
    }

    func activate(_ sessionID: UUID) {
        guard sessions.contains(where: { $0.id == sessionID }) else {
            return
        }

        activeSessionID = sessionID
    }

    func kind(for sessionID: UUID) -> TextResponseSessionKind? {
        sessions.first { $0.id == sessionID }?.kind
    }

    func messages(for sessionID: UUID) -> [TextResponseMessage] {
        sessions.first { $0.id == sessionID }?.messages ?? []
    }

    func isGenerating(sessionID: UUID) -> Bool {
        sessions.first { $0.id == sessionID }?.isGenerating ?? false
    }

    func appendUserMessage(sessionID: UUID, text: String) {
        activate(sessionID)
        mutate(sessionID) { session in
            session.messages.append(TextResponseMessage(role: .user, text: text))
            session.updatedAt = Date()
            session.lastError = nil
            session.isGenerating = true
        }
    }

    func appendAssistantMessage(sessionID: UUID, text: String, reasoning: String = "") {
        activate(sessionID)
        mutate(sessionID) { session in
            session.messages.append(TextResponseMessage(role: .assistant, text: text, reasoning: reasoning))
            session.updatedAt = Date()
            session.lastError = nil
            session.isGenerating = false
        }
    }

    func startAssistantStreamingMessage(sessionID: UUID) -> UUID? {
        let messageID = UUID()
        mutate(sessionID) { session in
            session.messages.append(TextResponseMessage(
                id: messageID,
                role: .assistant,
                text: "",
                isStreaming: true
            ))
            session.updatedAt = Date()
            session.lastError = nil
            session.isGenerating = true
        }

        return messages(for: sessionID).contains { $0.id == messageID } ? messageID : nil
    }

    func appendAssistantContentDelta(sessionID: UUID, messageID: UUID, delta: String) {
        guard !delta.isEmpty else {
            return
        }

        mutateMessage(sessionID: sessionID, messageID: messageID) { session, message in
            message.text += delta
            session.updatedAt = Date()
        }
    }

    func appendAssistantReasoningDelta(sessionID: UUID, messageID: UUID, delta: String) {
        guard !delta.isEmpty else {
            return
        }

        mutateMessage(sessionID: sessionID, messageID: messageID) { session, message in
            message.reasoning += delta
            session.updatedAt = Date()
        }
    }

    func finishAssistantStreamingMessage(sessionID: UUID, messageID: UUID, finalContent: String, finalReasoning: String) {
        mutateMessage(sessionID: sessionID, messageID: messageID) { session, message in
            message.text = finalContent
            message.reasoning = finalReasoning
            message.isStreaming = false
            message.streamError = nil
            session.updatedAt = Date()
            session.lastError = nil
            session.isGenerating = false
        }
    }

    func failAssistantStreamingMessage(sessionID: UUID, messageID: UUID, error: String) {
        mutateMessage(sessionID: sessionID, messageID: messageID) { session, message in
            message.isStreaming = false
            message.streamError = error
            session.updatedAt = Date()
            session.lastError = error
            session.isGenerating = false
        }
    }

    func setGenerating(_ isGenerating: Bool, sessionID: UUID) {
        mutate(sessionID) { session in
            session.isGenerating = isGenerating
            session.updatedAt = Date()
        }
    }

    func setError(_ message: String, sessionID: UUID) {
        mutate(sessionID) { session in
            session.lastError = message
            session.isGenerating = false
            session.updatedAt = Date()
        }
    }

    private func mutate(_ sessionID: UUID, _ update: (inout TextResponseSession) -> Void) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        update(&sessions[index])
        sessions.sort { first, second in
            first.updatedAt > second.updatedAt
        }
    }

    private func mutateMessage(
        sessionID: UUID,
        messageID: UUID,
        _ update: (inout TextResponseSession, inout TextResponseMessage) -> Void
    ) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID }),
              let messageIndex = sessions[sessionIndex].messages.firstIndex(where: { $0.id == messageID })
        else {
            return
        }

        var session = sessions[sessionIndex]
        var message = session.messages[messageIndex]
        update(&session, &message)
        session.messages[messageIndex] = message
        sessions[sessionIndex] = session
        sessions.sort { first, second in
            first.updatedAt > second.updatedAt
        }
    }

    private static func sessionTitle(from text: String, fallback: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > 48 else {
            return cleaned.isEmpty ? fallback : cleaned
        }

        let endIndex = cleaned.index(cleaned.startIndex, offsetBy: 48)
        return "\(cleaned[..<endIndex])..."
    }

    private static func fallbackTitle(for kind: TextResponseSessionKind) -> String {
        switch kind {
        case .text:
            return "Text response"
        case .voice:
            return "Voice response"
        }
    }
}
