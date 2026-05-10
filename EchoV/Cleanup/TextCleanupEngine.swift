import Foundation

protocol TextCleanupEngine: Sendable {
    var id: String { get }
    var displayName: String { get }

    func clean(_ transcript: Transcript) async throws -> CleanedText
}

struct CleanedText: Equatable, Sendable {
    let text: String
}
