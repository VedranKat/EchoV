import Foundation

enum VoiceModePromptComposer {
    static func compose(userPrompt: String, selectedText: String?) -> String {
        let prompt = normalized(userPrompt)
        let selection = normalized(selectedText ?? "")

        guard !selection.isEmpty else {
            return prompt
        }

        guard !prompt.isEmpty else {
            return "Background text:\n\(selection)"
        }

        return "Background text:\n\(selection)\n\nWhat I want:\n\(prompt)"
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
