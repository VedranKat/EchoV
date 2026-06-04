import Foundation

enum LiveSubtitlePostProcessingPolicy {
    static let cleanupTimeoutSeconds: UInt64 = 4
    static let translationTimeoutSeconds: UInt64 = 8
    static let catchUpQueueDepth = 1
    static let catchUpDelaySeconds: TimeInterval = 5
    static let maximumCleanupSubtitleLagSeconds: TimeInterval = LiveSubtitleDisplaySyncPolicy.maximumCaptionStartLagSeconds
    static let maximumTranslationSubtitleLagSeconds: TimeInterval = 20

    static func timeoutSeconds(for mode: LiveSubtitleMode) -> UInt64 {
        switch mode {
        case .rawCaptions:
            0
        case .cleanedCaptions:
            cleanupTimeoutSeconds
        case .translatedSubtitles:
            translationTimeoutSeconds
        }
    }

    static func shouldSkip(
        mode: LiveSubtitleMode,
        pendingChunkCount: Int,
        currentDelaySeconds: TimeInterval
    ) -> Bool {
        switch mode {
        case .rawCaptions:
            return false
        case .translatedSubtitles:
            return false
        case .cleanedCaptions:
            if currentDelaySeconds >= catchUpDelaySeconds {
                return true
            }

            return pendingChunkCount >= catchUpQueueDepth
        }
    }

    static func maximumProcessedSubtitleLagSeconds(for mode: LiveSubtitleMode) -> TimeInterval {
        switch mode {
        case .rawCaptions:
            0
        case .cleanedCaptions:
            maximumCleanupSubtitleLagSeconds
        case .translatedSubtitles:
            maximumTranslationSubtitleLagSeconds
        }
    }

    static func shouldDisplaySourceCaptionBeforeProcessing(
        mode: LiveSubtitleMode,
        showsRawWhileProcessing: Bool,
        skipPostProcessing: Bool
    ) -> Bool {
        switch mode {
        case .rawCaptions:
            return true
        case .cleanedCaptions:
            return showsRawWhileProcessing || skipPostProcessing
        case .translatedSubtitles:
            return false
        }
    }

    static func allowsSourceCaptionFallback(for mode: LiveSubtitleMode) -> Bool {
        switch mode {
        case .rawCaptions, .cleanedCaptions:
            true
        case .translatedSubtitles:
            false
        }
    }
}
