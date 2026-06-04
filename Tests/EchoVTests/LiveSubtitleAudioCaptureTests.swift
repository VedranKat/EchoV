import AVFoundation
import XCTest
@testable import EchoV

@MainActor
final class LiveSubtitleAudioCaptureTests: XCTestCase {
    func testContinuousSpeechAfterForcedBoundaryDoesNotEmitTinyChunks() async throws {
        let sampleRate = 16_000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var chunks: [LiveSubtitleAudioChunk] = []
        let receivedChunks = expectation(description: "received forced-boundary chunks")
        receivedChunks.expectedFulfillmentCount = 2

        let session = try LiveSubtitleCaptureSession(
            format: format,
            configuration: LiveSubtitleChunkConfiguration(
                maxChunkSeconds: 1.5,
                silenceTimeoutSeconds: 1.0,
                minimumSpeechSeconds: 0.20,
                preRollSeconds: 0.10,
                overlapSeconds: 0.20,
                sensitivity: .high
            ),
            startedAt: startedAt,
            onChunkReady: { chunk in
                chunks.append(chunk)
                try? FileManager.default.removeItem(at: chunk.fileURL)
                receivedChunks.fulfill()
            },
            onError: { error in
                XCTFail("Unexpected live subtitle capture error: \(error.localizedDescription)")
            }
        )

        let buffer = try Self.toneBuffer(format: format, duration: 0.10)
        for index in 1...34 {
            session.process(buffer, receivedAt: startedAt.addingTimeInterval(Double(index) * 0.10))
        }

        await fulfillment(of: [receivedChunks], timeout: 1.0)
        session.cancel(deleteCandidate: true)

        XCTAssertEqual(chunks.count, 2)
        XCTAssertTrue(
            chunks.allSatisfy { $0.duration >= 1.2 },
            "Forced-boundary continuation should keep recording from the replay point instead of emitting tiny chunks."
        )
    }

    private static func toneBuffer(format: AVAudioFormat, duration: TimeInterval) throws -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw TestAudioError.couldNotCreateBuffer
        }

        buffer.frameLength = frameCount
        guard let samples = buffer.floatChannelData?[0] else {
            throw TestAudioError.couldNotCreateBuffer
        }

        for frame in 0..<Int(frameCount) {
            samples[frame] = 0.20 * sin(Float(frame) * 0.08)
        }
        return buffer
    }

    private enum TestAudioError: Error {
        case couldNotCreateBuffer
    }
}
