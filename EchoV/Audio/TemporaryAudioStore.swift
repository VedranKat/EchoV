import Foundation
import Observation

@MainActor
@Observable
final class TemporaryAudioStore {
    private(set) var lastFailedAudioURL: URL?

    func rememberFailedAudio(_ url: URL) {
        lastFailedAudioURL = url
    }

    func clearFailedAudio() {
        lastFailedAudioURL = nil
    }

    func delete(_ urls: [URL]) {
        for url in Set(urls) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
