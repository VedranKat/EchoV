import Foundation

protocol ASREngine: Sendable {
    var id: String { get }
    var displayName: String { get }
    var onStatusUpdate: (@Sendable (String) -> Void)? { get set }

    func prepare() async throws
    func transcribe(audioURL: URL, options: ASROptions) async throws -> Transcript
}

struct UnconfiguredASREngine: ASREngine {
    let id = "unconfigured"
    let displayName = "No ASR Model Selected"
    var onStatusUpdate: (@Sendable (String) -> Void)?

    func prepare() async throws {
        throw AppError.modelNotSelected
    }

    func transcribe(audioURL: URL, options: ASROptions) async throws -> Transcript {
        throw AppError.modelNotSelected
    }
}
