import Foundation

struct ASRModelSelection: Equatable, Sendable {
    let url: URL
    let displayName: String
    let selectedAt: Date
    let validation: ModelValidationResult
}
