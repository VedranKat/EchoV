import Foundation

struct SpeakerMatchResult: Equatable, Sendable {
    let similarity: Double
    let threshold: Double

    var isMatch: Bool {
        similarity >= threshold
    }
}

protocol SpeakerVerificationService: Sendable {
    func enroll(audioURL: URL) async throws -> SpeakerProfile
    func score(audioURL: URL, profile: SpeakerProfile, threshold: Double) async throws -> SpeakerMatchResult
}
