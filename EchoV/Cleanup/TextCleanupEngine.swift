import Foundation

protocol TextCleanupEngine: Sendable {
    var id: String { get }
    var displayName: String { get }

    func prepare() async throws
    func clean(_ transcript: Transcript, level: PostProcessingLevel) async throws -> CleanedText
    func shutdown() async
}

struct CleanedText: Equatable, Sendable {
    let text: String
}

extension TextCleanupEngine {
    func prepare() async throws {}
    func shutdown() async {}
}
