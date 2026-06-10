import Foundation

struct AssistantContextWindowConfiguration: Equatable, Sendable {
    let contextWindowTokens: Int
    let responseReserveTokens: Int
    let safetyRatio: Double
    let maximumRecentMessages: Int?

    init(
        contextWindowTokens: Int,
        responseReserveTokens: Int,
        safetyRatio: Double = 0.70,
        maximumRecentMessages: Int? = nil
    ) {
        self.contextWindowTokens = max(1, contextWindowTokens)
        self.responseReserveTokens = max(0, responseReserveTokens)
        self.safetyRatio = min(max(safetyRatio, 0.10), 1.0)
        self.maximumRecentMessages = maximumRecentMessages
    }

    var inputBudgetTokens: Int {
        let remaining = max(1, contextWindowTokens - responseReserveTokens)
        return max(256, Int(Double(remaining) * safetyRatio))
    }
}

enum AssistantContextWindow {
    private static let fixedOverheadTokens = 500
    private static let perMessageOverheadTokens = 8
    private static let currentMessageTruncationNotice = "\n\n[Current message truncated by EchoV to fit the configured context window.]"

    static func reduce(
        _ request: ChatGenerationRequest,
        configuration: AssistantContextWindowConfiguration
    ) -> ChatGenerationRequest {
        let systemMessages = request.messages.filter { $0.role == .system }
        var conversationMessages = request.messages.filter { $0.role != .system }

        if let maximumRecentMessages = configuration.maximumRecentMessages,
           conversationMessages.count > maximumRecentMessages
        {
            conversationMessages = Array(conversationMessages.suffix(maximumRecentMessages))
        }

        trimLeadingAssistantMessages(from: &conversationMessages)

        var messages = systemMessages + conversationMessages
        while estimatedTokens(for: messages) > configuration.inputBudgetTokens,
              conversationMessages.count > 1
        {
            conversationMessages.removeFirst()
            trimLeadingAssistantMessages(from: &conversationMessages)
            messages = systemMessages + conversationMessages
        }

        if estimatedTokens(for: messages) > configuration.inputBudgetTokens {
            messages = trimLatestConversationMessage(
                systemMessages: systemMessages,
                conversationMessages: conversationMessages,
                inputBudgetTokens: configuration.inputBudgetTokens
            )
        }

        return ChatGenerationRequest(
            messages: messages,
            temperature: request.temperature,
            topP: request.topP,
            maxTokens: request.maxTokens,
            policy: request.policy
        )
    }

    static func estimatedTokens(for messages: [ChatGenerationMessage]) -> Int {
        let characterCount = messages.reduce(0) { partialResult, message in
            partialResult + message.content.count
        }
        return Int(ceil(Double(characterCount) / 3.0))
            + (messages.count * perMessageOverheadTokens)
            + fixedOverheadTokens
    }

    private static func trimLeadingAssistantMessages(from messages: inout [ChatGenerationMessage]) {
        while messages.first?.role == .assistant {
            messages.removeFirst()
        }
    }

    private static func trimLatestConversationMessage(
        systemMessages: [ChatGenerationMessage],
        conversationMessages: [ChatGenerationMessage],
        inputBudgetTokens: Int
    ) -> [ChatGenerationMessage] {
        guard var latestMessage = conversationMessages.last else {
            return systemMessages
        }

        let prefixMessages = systemMessages + conversationMessages.dropLast()
        let availableTokens = max(
            128,
            inputBudgetTokens - estimatedTokens(for: prefixMessages) - perMessageOverheadTokens
        )
        let maxCharacters = max(500, Int(Double(availableTokens) * 2.2))
        guard latestMessage.content.count > maxCharacters else {
            return prefixMessages + [latestMessage]
        }

        let endIndex = latestMessage.content.index(
            latestMessage.content.startIndex,
            offsetBy: maxCharacters
        )
        latestMessage = ChatGenerationMessage(
            role: latestMessage.role,
            content: "\(latestMessage.content[..<endIndex])\(currentMessageTruncationNotice)"
        )
        return prefixMessages + [latestMessage]
    }
}
