import AVFoundation
import XCTest
@testable import EchoV

@MainActor
final class VoiceActivatedAudioCaptureTests: XCTestCase {
    func testMaximumDurationDiscardsCandidateUntilSilenceThenRearms() async throws {
        let sampleRate = 16_000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let startedAt = Date()
        let tone = try Self.toneBuffer(format: format, duration: 0.10)
        let silence = try Self.silenceBuffer(format: format, duration: 0.10)
        var utterances: [RecordedAudio] = []
        var maximumDurationExceededCount = 0
        let maximumDurationExceeded = expectation(description: "maximum duration exceeded")
        let shortUtteranceEnded = expectation(description: "short utterance ended after rearm")

        let session = try VoiceGateCaptureSession(
            format: format,
            configuration: VoiceGateCaptureConfiguration(
                silenceTimeoutSeconds: 0.6,
                sensitivity: .high,
                maximumDurationSeconds: 2.0
            ),
            onSpeechStarted: { _ in },
            onUtteranceEnded: { recordedAudio in
                utterances.append(recordedAudio)
                try? FileManager.default.removeItem(at: recordedAudio.fileURL)
                shortUtteranceEnded.fulfill()
            },
            onMaximumSpeechDurationExceeded: {
                maximumDurationExceededCount += 1
                maximumDurationExceeded.fulfill()
            },
            onError: { error in
                XCTFail("Unexpected voice-gate capture error: \(error.localizedDescription)")
            }
        )

        for index in 1...40 {
            session.process(tone, receivedAt: startedAt.addingTimeInterval(Double(index) * 0.10))
        }

        await fulfillment(of: [maximumDurationExceeded], timeout: 1.0)
        XCTAssertTrue(utterances.isEmpty)
        XCTAssertEqual(maximumDurationExceededCount, 1)

        for index in 41...48 {
            session.process(silence, receivedAt: startedAt.addingTimeInterval(Double(index) * 0.10))
        }
        for index in 49...55 {
            session.process(tone, receivedAt: startedAt.addingTimeInterval(Double(index) * 0.10))
        }
        for index in 56...63 {
            session.process(silence, receivedAt: startedAt.addingTimeInterval(Double(index) * 0.10))
        }

        await fulfillment(of: [shortUtteranceEnded], timeout: 1.0)
        session.cancel()

        XCTAssertEqual(utterances.count, 1)
        XCTAssertEqual(maximumDurationExceededCount, 1)
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

    private static func silenceBuffer(format: AVAudioFormat, duration: TimeInterval) throws -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw TestAudioError.couldNotCreateBuffer
        }

        buffer.frameLength = frameCount
        return buffer
    }

    private enum TestAudioError: Error {
        case couldNotCreateBuffer
    }
}
