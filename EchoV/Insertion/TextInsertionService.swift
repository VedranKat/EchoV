import Foundation

protocol TextInsertionService: Sendable {
    func insert(_ text: String) async throws -> InsertionResult
}

struct InsertionResult: Equatable, Sendable {
    let insertedDirectly: Bool
    let copiedToClipboard: Bool
    let restoredPreviousClipboard: Bool

    init(
        insertedDirectly: Bool,
        copiedToClipboard: Bool,
        restoredPreviousClipboard: Bool = false
    ) {
        self.insertedDirectly = insertedDirectly
        self.copiedToClipboard = copiedToClipboard
        self.restoredPreviousClipboard = restoredPreviousClipboard
    }
}
