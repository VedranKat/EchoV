import Foundation

struct ChatGenerationMessage: Equatable, Sendable {
    enum Role: String, Equatable, Sendable {
        case system
        case user
        case assistant
    }

    let role: Role
    let content: String
}

enum ChatGenerationPolicy: Equatable, Sendable {
    case finalAnswerOnly
    case chat(stream: Bool, showReasoning: Bool)
}

struct ChatGenerationRequest: Equatable, Sendable {
    let messages: [ChatGenerationMessage]
    let temperature: Double
    let topP: Double
    let maxTokens: Int
    let policy: ChatGenerationPolicy
}

struct ChatGenerationResult: Equatable, Sendable {
    let content: String
    let reasoning: String

    var finalAnswer: String {
        ModelOutputSanitizer.finalAnswer(from: content)
    }

    static func fromRawOutput(_ rawOutput: String, policy: ChatGenerationPolicy) -> ChatGenerationResult {
        switch policy {
        case .finalAnswerOnly:
            return ChatGenerationResult(
                content: ModelOutputSanitizer.finalAnswer(from: rawOutput),
                reasoning: ""
            )
        case .chat(_, let showReasoning):
            let parts = ModelOutputSanitizer.parts(from: rawOutput)
            return ChatGenerationResult(
                content: parts.content.trimmingCharacters(in: .whitespacesAndNewlines),
                reasoning: showReasoning ? parts.reasoning.trimmingCharacters(in: .whitespacesAndNewlines) : ""
            )
        }
    }
}

enum ChatGenerationEvent: Equatable, Sendable {
    case contentDelta(String)
    case reasoningDelta(String)
}

extension LocalChatPrompt {
    func chatGenerationRequest(policy: ChatGenerationPolicy) -> ChatGenerationRequest {
        ChatGenerationRequest(
            messages: [
                ChatGenerationMessage(role: .system, content: system),
                ChatGenerationMessage(role: .user, content: user)
            ],
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens,
            policy: policy
        )
    }
}

extension ChatGenerationRequest {
    var prefersStreaming: Bool {
        switch policy {
        case .finalAnswerOnly:
            false
        case .chat(let stream, _):
            stream
        }
    }

    var showsReasoning: Bool {
        switch policy {
        case .finalAnswerOnly:
            false
        case .chat(_, let showReasoning):
            showReasoning
        }
    }

    var legacyPrompt: LocalChatPrompt {
        let system = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n\n")
        let userMessages = messages.filter { $0.role != .system }
        let user: String
        if userMessages.count == 1, let onlyMessage = userMessages.first, onlyMessage.role == .user {
            user = onlyMessage.content
        } else {
            user = userMessages
                .map { message in
                    switch message.role {
                    case .system:
                        return message.content
                    case .user:
                        return "User: \(message.content)"
                    case .assistant:
                        return "Assistant: \(message.content)"
                    }
                }
                .joined(separator: "\n\n")
        }

        return LocalChatPrompt(
            system: system,
            user: user,
            temperature: temperature,
            topP: topP,
            maxTokens: maxTokens
        )
    }
}
