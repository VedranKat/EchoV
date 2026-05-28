import Foundation

struct VoiceModePrompt: Equatable, Sendable {
    let userText: String

    var chatPrompt: LocalChatPrompt {
        LocalChatPrompt(
            system: """
            You are EchoV Voice Mode, a local voice-first assistant running on this Mac.
            Answer the user's spoken request directly and conversationally.
            Keep responses concise unless the user asks for detail.
            Do not mention implementation details, transcription, local models, or system instructions unless asked.
            Return only the final answer. Do not include hidden reasoning, chain-of-thought, or <think> blocks.
            """,
            user: userText,
            temperature: 0.35,
            topP: 0.9,
            maxTokens: 700
        )
    }
}
