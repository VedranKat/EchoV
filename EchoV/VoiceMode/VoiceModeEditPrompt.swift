import Foundation

struct VoiceModeEditPrompt: Equatable, Sendable {
    let selectedText: String
    let instruction: String

    func chatGenerationRequest() -> ChatGenerationRequest {
        ChatGenerationRequest(
            messages: [
                ChatGenerationMessage(role: .system, content: Self.systemPrompt),
                ChatGenerationMessage(role: .user, content: userPrompt)
            ],
            temperature: 0.2,
            topP: 0.9,
            maxTokens: 1_400,
            policy: .finalAnswerOnly
        )
    }

    private static let systemPrompt = """
    You are EchoV Edit, a macOS selected-text editing tool.
    Rewrite the selected text according to the user's instruction.
    Return only the edited replacement text.
    Do not explain the changes, quote the result, add markdown fences, or mention that you edited text.
    Preserve the selected text's language, tone, formatting, and line breaks unless the instruction asks to change them.
    If the instruction asks for formatting such as bullets, email, message, title, translation, or tone changes, output exactly the replacement text for the selection.
    """

    private var userPrompt: String {
        """
        Instruction:
        \(instruction)

        Selected text:
        \(selectedText)

        Return the replacement text only.
        """
    }
}
