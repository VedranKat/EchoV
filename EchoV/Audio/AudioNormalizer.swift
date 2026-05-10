import Foundation

struct AudioNormalizer: Sendable {
    func normalize(_ audioURL: URL) async throws -> URL {
        // Real implementation will convert to ASR-ready 16 kHz mono Float samples.
        audioURL
    }
}
