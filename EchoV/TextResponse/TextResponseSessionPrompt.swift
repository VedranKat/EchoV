import Foundation

struct TextResponseSessionPrompt {
    let messages: [TextResponseMessage]

    private static let baseSystemPrompt = """
    You are EchoV Text Response Mode, a concise assistant running inside a macOS chat session.
    Continue the conversation naturally. Answer the latest user message directly.
    Keep responses useful, compact, and easy to scan in a small Mac window.
    """

    var chatPrompt: LocalChatPrompt {
        let transcript = messages
            .map { message in
                switch message.role {
                case .user:
                    return "User: \(message.text)"
                case .assistant:
                    return "Assistant: \(message.text)"
                }
            }
            .joined(separator: "\n\n")

        return LocalChatPrompt(
            system: Self.baseSystemPrompt,
            user: transcript,
            temperature: 0.3,
            topP: 0.9,
            maxTokens: 768
        )
    }

    func chatGenerationRequest(policy: ChatGenerationPolicy) -> ChatGenerationRequest {
        var chatMessages = [
            ChatGenerationMessage(role: .system, content: systemPrompt(for: policy))
        ]

        chatMessages.append(contentsOf: messages.compactMap { message in
            guard !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }

            switch message.role {
            case .user:
                return ChatGenerationMessage(role: .user, content: message.text)
            case .assistant:
                return ChatGenerationMessage(role: .assistant, content: message.text)
            }
        })

        return ChatGenerationRequest(
            messages: chatMessages,
            temperature: 0.3,
            topP: 0.9,
            maxTokens: 768,
            policy: policy
        )
    }

    private func systemPrompt(for policy: ChatGenerationPolicy) -> String {
        switch policy {
        case .finalAnswerOnly:
            return """
            \(Self.baseSystemPrompt)
            Return only the final answer. Do not include hidden reasoning, chain-of-thought, or <think> blocks.
            """
        case .chat(_, let showReasoning):
            if showReasoning {
                return Self.baseSystemPrompt
            }

            return """
            \(Self.baseSystemPrompt)
            Return only the final answer. Do not include hidden reasoning, chain-of-thought, or <think> blocks.
            """
        }
    }
}
