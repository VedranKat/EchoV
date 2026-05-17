import Foundation

struct SpeakerProfile: Codable, Equatable, Sendable {
    let version: Int
    let id: String
    let modelID: String
    let embedding: [Double]
    let createdAt: Date

    init(
        version: Int = 1,
        id: String = "default",
        modelID: String,
        embedding: [Double],
        createdAt: Date = Date()
    ) {
        self.version = version
        self.id = id
        self.modelID = modelID
        self.embedding = embedding
        self.createdAt = createdAt
    }
}
