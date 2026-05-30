import Foundation

struct PostProcessingModelSelection: Equatable, Sendable {
    let url: URL
    let displayName: String
    let modelDefinition: PostProcessingModelDefinition
    let selectedAt: Date
    let validation: ModelValidationResult
}
