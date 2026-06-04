import XCTest
@testable import EchoV

final class LiveSubtitlePostProcessingPolicyTests: XCTestCase {
    func testTranslationDoesNotSkipForOneQueuedChunkWhenDelayIsLow() {
        XCTAssertFalse(
            LiveSubtitlePostProcessingPolicy.shouldSkip(
                mode: .translatedSubtitles,
                pendingChunkCount: 1,
                currentDelaySeconds: 1.0
            )
        )
    }

    func testTranslationDoesNotSkipWhenLiveDelayIsHigh() {
        XCTAssertFalse(
            LiveSubtitlePostProcessingPolicy.shouldSkip(
                mode: .translatedSubtitles,
                pendingChunkCount: 0,
                currentDelaySeconds: LiveSubtitlePostProcessingPolicy.catchUpDelaySeconds
            )
        )
    }

    func testCleanupSkipsWhenLiveDelayIsHigh() {
        XCTAssertTrue(
            LiveSubtitlePostProcessingPolicy.shouldSkip(
                mode: .cleanedCaptions,
                pendingChunkCount: 0,
                currentDelaySeconds: LiveSubtitlePostProcessingPolicy.catchUpDelaySeconds
            )
        )
    }

    func testCleanupStillSkipsForQueuedChunks() {
        XCTAssertTrue(
            LiveSubtitlePostProcessingPolicy.shouldSkip(
                mode: .cleanedCaptions,
                pendingChunkCount: LiveSubtitlePostProcessingPolicy.catchUpQueueDepth,
                currentDelaySeconds: 1.0
            )
        )
    }

    func testTranslationGetsLongerTimeoutThanCleanup() {
        XCTAssertGreaterThan(
            LiveSubtitlePostProcessingPolicy.timeoutSeconds(for: .translatedSubtitles),
            LiveSubtitlePostProcessingPolicy.timeoutSeconds(for: .cleanedCaptions)
        )
    }

    func testTranslationAllowsMoreProcessedSubtitleLagThanCleanup() {
        XCTAssertGreaterThan(
            LiveSubtitlePostProcessingPolicy.maximumProcessedSubtitleLagSeconds(for: .translatedSubtitles),
            LiveSubtitlePostProcessingPolicy.maximumProcessedSubtitleLagSeconds(for: .cleanedCaptions)
        )
    }

    func testTranslationDoesNotDisplaySourceCaptionBeforeProcessing() {
        XCTAssertFalse(
            LiveSubtitlePostProcessingPolicy.shouldDisplaySourceCaptionBeforeProcessing(
                mode: .translatedSubtitles,
                showsRawWhileProcessing: true,
                skipPostProcessing: false
            )
        )
    }

    func testCleanedCaptionsCanDisplaySourceCaptionBeforeProcessing() {
        XCTAssertTrue(
            LiveSubtitlePostProcessingPolicy.shouldDisplaySourceCaptionBeforeProcessing(
                mode: .cleanedCaptions,
                showsRawWhileProcessing: true,
                skipPostProcessing: false
            )
        )
    }

    func testTranslationDoesNotAllowSourceCaptionFallback() {
        XCTAssertFalse(
            LiveSubtitlePostProcessingPolicy.allowsSourceCaptionFallback(for: .translatedSubtitles)
        )
    }

    func testCleanedCaptionsAllowSourceCaptionFallback() {
        XCTAssertTrue(
            LiveSubtitlePostProcessingPolicy.allowsSourceCaptionFallback(for: .cleanedCaptions)
        )
    }
}
