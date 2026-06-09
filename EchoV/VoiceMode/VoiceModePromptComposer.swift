import Foundation

enum VoiceModePromptComposer {
    private static let maximumSelectedTextCharacters = 24_000
    private static let truncationNotice = "[Selected text truncated by EchoV because it was too long.]"

    static func compose(userPrompt: String, selectedText: String?) -> String {
        let prompt = normalized(userPrompt)
        let selection = preparedSelection(from: selectedText ?? "")

        guard !selection.isEmpty else {
            return prompt
        }

        guard !prompt.isEmpty else {
            return "Selected text:\n\(selection)"
        }

        return "Selected text:\n\(selection)\n\nWhat I want:\n\(prompt)"
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func preparedSelection(from text: String) -> String {
        let selection = normalized(text)
        guard selection.count > maximumSelectedTextCharacters else {
            return selection
        }

        let endIndex = selection.index(selection.startIndex, offsetBy: maximumSelectedTextCharacters)
        return "\(selection[..<endIndex])\n\n\(truncationNotice)"
    }
}
