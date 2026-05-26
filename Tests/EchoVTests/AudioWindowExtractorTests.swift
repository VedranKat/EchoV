import AVFoundation
import XCTest
@testable import EchoV

final class AudioWindowExtractorTests: XCTestCase {
    func testExtractsLeadingAndOverlappingWindows() throws {
        let folder = try temporaryFolder()
        let audioURL = folder.appendingPathComponent("source.wav")
        try makeSilentAudio(at: audioURL, duration: 4.0)

        let extractor = AudioWindowExtractor(temporaryDirectory: folder)

        let leadingWindows = try extractor.extractLeadingWindow(from: audioURL, duration: 2.5)
        XCTAssertEqual(leadingWindows.count, 1)
        XCTAssertEqual(leadingWindows[0].startTime, 0, accuracy: 0.01)
        XCTAssertEqual(leadingWindows[0].duration, 2.5, accuracy: 0.05)
        XCTAssertTrue(FileManager.default.fileExists(atPath: leadingWindows[0].fileURL.path))

        let overlappingWindows = try extractor.extractOverlappingWindows(
            from: audioURL,
            windowDuration: 2.5,
            hopDuration: 1.25,
            minimumWindowDuration: 1.25
        )
        XCTAssertEqual(overlappingWindows.count, 3)
        assertTimeIntervals(overlappingWindows.map(\.startTime), equal: [0, 1.25, 2.5], accuracy: 0.01)
        assertTimeIntervals(overlappingWindows.map(\.duration), equal: [2.5, 2.5, 1.5], accuracy: 0.05)
        XCTAssertTrue(overlappingWindows.allSatisfy { FileManager.default.fileExists(atPath: $0.fileURL.path) })
    }

    private func makeSilentAudio(at url: URL, duration: TimeInterval) throws {
        let sampleRate: Double = 16_000
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Could not create audio buffer")
            return
        }

        buffer.frameLength = frameCount
        if let samples = buffer.floatChannelData?[0] {
            for frame in 0..<Int(frameCount) {
                samples[frame] = 0
            }
        }

        try file.write(from: buffer)
    }

    private func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: folder)
        }
        return folder
    }

    private func assertTimeIntervals(
        _ values: [TimeInterval],
        equal expectedValues: [TimeInterval],
        accuracy: TimeInterval,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(values.count, expectedValues.count, file: file, line: line)
        Swift.zip(values, expectedValues).forEach { lhs, rhs in
            XCTAssertEqual(lhs, rhs, accuracy: accuracy, file: file, line: line)
        }
    }
}
