import Foundation
import Observation

@MainActor
@Observable
final class TranscriptHistoryStore {
    private let maximumItems: Int
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private(set) var items: [TranscriptHistoryItem] = []

    init(
        maximumItems: Int = 50,
        fileManager: FileManager = .default
    ) {
        self.maximumItems = maximumItems

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = appSupport.appendingPathComponent("EchoV", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("history.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() async {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            items = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            items = try decoder.decode([TranscriptHistoryItem].self, from: data)
            trimToLimit()
        } catch {
            items = []
        }
    }

    func append(_ transcript: Transcript) async {
        items.insert(TranscriptHistoryItem(transcript: transcript), at: 0)
        trimToLimit()
        await save()
    }

    func clear() async {
        items.removeAll()
        await save()
    }

    private func trimToLimit() {
        if items.count > maximumItems {
            items = Array(items.prefix(maximumItems))
        }
    }

    private func save() async {
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // History is a recovery convenience, not a critical app path.
        }
    }
}
