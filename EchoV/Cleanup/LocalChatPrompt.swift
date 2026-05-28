import Foundation

struct LocalChatPrompt: Equatable, Sendable {
    let system: String
    let user: String
    let temperature: Double
    let topP: Double
    let maxTokens: Int

    init(
        system: String,
        user: String,
        temperature: Double = 0.2,
        topP: Double = 0.9,
        maxTokens: Int = 512
    ) {
        self.system = system
        self.user = user
        self.temperature = temperature
        self.topP = topP
        self.maxTokens = maxTokens
    }
}
