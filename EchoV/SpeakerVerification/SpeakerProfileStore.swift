import Foundation
import Observation

@MainActor
@Observable
final class SpeakerProfileStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    var profile: SpeakerProfile?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        self.profile = try? loadProfile()
    }

    func refresh() {
        profile = try? loadProfile()
    }

    func save(_ profile: SpeakerProfile) throws {
        try fileManager.createDirectory(at: profileDirectoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(profile)
        try data.write(to: profileURL, options: .atomic)
        self.profile = profile
    }

    func deleteProfile() {
        try? fileManager.removeItem(at: profileURL)
        profile = nil
    }

    func deleteAllProfiles() {
        try? fileManager.removeItem(at: profileDirectoryURL)
        profile = nil
    }

    private func loadProfile() throws -> SpeakerProfile? {
        guard fileManager.fileExists(atPath: profileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: profileURL)
        return try decoder.decode(SpeakerProfile.self, from: data)
    }

    private var profileURL: URL {
        profileDirectoryURL.appendingPathComponent("default-profile.json")
    }

    private var profileDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("EchoV/SpeakerProfiles", isDirectory: true)
    }
}
