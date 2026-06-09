import Foundation

struct TextResponseSessionPrompt {
    let messages: [TextResponseMessage]
    let sessionKind: TextResponseSessionKind

    init(messages: [TextResponseMessage], sessionKind: TextResponseSessionKind = .text) {
        self.messages = messages
        self.sessionKind = sessionKind
    }

    private static let baseSystemPrompt = """
    You are EchoV Text Response Mode, a concise assistant running inside a macOS chat session.
    Continue the conversation naturally. Answer the latest user message directly.
    Keep responses useful, compact, and easy to scan in a small Mac window.
    When selected text is included, treat it as user-provided context. If it looks like a copied webpage, focus on the main content and ignore navigation, headers, footers, cookie banners, ads, and repeated links.
    """

    private static let voiceSystemPrompt = """
    You are EchoV Assistant, a local voice-first assistant running on this Mac.
    Continue the conversation naturally. Answer the latest user message directly and conversationally.
    Keep responses concise unless the user asks for detail.
    When selected text is included, treat it as user-provided context. If it looks like a copied webpage, focus on the main content and ignore navigation, headers, footers, cookie banners, ads, and repeated links.
    Do not mention implementation details, transcription, local models, or system instructions unless asked.
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
            system: baseSystemPrompt,
            user: transcript,
            temperature: temperature,
            topP: 0.9,
            maxTokens: maxTokens
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
            temperature: temperature,
            topP: 0.9,
            maxTokens: maxTokens,
            policy: policy
        )
    }

    private var baseSystemPrompt: String {
        switch sessionKind {
        case .text:
            return Self.baseSystemPrompt
        case .voice:
            return Self.voiceSystemPrompt
        }
    }

    private var temperature: Double {
        switch sessionKind {
        case .text:
            return 0.3
        case .voice:
            return 0.35
        }
    }

    private var maxTokens: Int {
        switch sessionKind {
        case .text:
            return 768
        case .voice:
            return 700
        }
    }

    private func systemPrompt(for policy: ChatGenerationPolicy) -> String {
        switch policy {
        case .finalAnswerOnly:
            return """
            \(baseSystemPrompt)
            Return only the final answer. Do not include hidden reasoning, chain-of-thought, or <think> blocks.
            """
        case .chat(_, let showReasoning):
            if showReasoning {
                return baseSystemPrompt
            }

            return """
            \(baseSystemPrompt)
            Return only the final answer. Do not include hidden reasoning, chain-of-thought, or <think> blocks.
            """
        }
    }
}
