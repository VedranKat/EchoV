import Foundation
import XCTest
@testable import EchoV

@MainActor
final class DictationPipelineReplacementTests: XCTestCase {
    func testInsertReplacementTextPreservesSurroundingWhitespace() async throws {
        let appState = AppState()
        let insertion = CapturingInsertionService()
        let pipeline = DictationPipeline(
            appState: appState,
            recorder: StubAudioRecorder(),
            normalizer: AudioNormalizer(),
            asrEngine: UnconfiguredASREngine(),
            cleanupEngine: StubTextCleanupEngine(),
            insertion: insertion,
            history: TranscriptHistoryStore(),
            temporaryAudioStore: TemporaryAudioStore(),
            isHistoryEnabled: { false },
            shouldDeleteTemporaryAudio: { true },
            isPostProcessingEnabled: { false },
            postProcessingLevel: { .balanced }
        )

        let replacement = "    let value = compute()\n"
        let transcript = try await pipeline.insertReplacementText(replacement)
        let insertedTexts = await insertion.insertedTexts()

        XCTAssertEqual(insertedTexts, [replacement])
        XCTAssertEqual(transcript.text, replacement)
        if case .completed(let completedTranscript) = appState.state {
            XCTAssertEqual(completedTranscript.text, replacement)
        } else {
            XCTFail("Expected replacement insertion to complete.")
        }
    }
}

private struct StubAudioRecorder: AudioRecorder {
    func start() async throws -> RecordedAudio {
        throw AppError.recordingFailed(details: "Stub recorder does not record.")
    }

    func stop() async throws -> RecordedAudio {
        throw AppError.recordingFailed(details: "Stub recorder does not record.")
    }
}

private struct StubTextCleanupEngine: TextCleanupEngine {
    let id = "stub-cleanup"
    let displayName = "Stub Cleanup"

    func clean(_ transcript: Transcript, level: PostProcessingLevel) async throws -> CleanedText {
        CleanedText(text: transcript.text)
    }
}

private actor CapturingInsertionService: TextInsertionService {
    private var texts: [String] = []

    func insert(_ text: String) async throws -> InsertionResult {
        texts.append(text)
        return InsertionResult(insertedDirectly: true, copiedToClipboard: true)
    }

    func insertedTexts() -> [String] {
        texts
    }
}
