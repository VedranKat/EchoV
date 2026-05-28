import XCTest
@testable import EchoV

final class VoiceModePromptEndingPolicyTests: XCTestCase {
    func testFixedPauseAlwaysUsesConfiguredPause() {
        let policy = VoiceModePromptEndingPolicy(
            mode: .fixedPause,
            fixedPauseSeconds: 1.2,
            adaptiveFastPauseSeconds: 0.6,
            adaptiveMinimumSpeechSeconds: 1.0,
            stopPhrase: "send it"
        )

        XCTAssertEqual(policy.silenceTimeout(afterSpeechDuration: 0.2), 1.2)
        XCTAssertEqual(policy.silenceTimeout(afterSpeechDuration: 5.0), 1.2)
        XCTAssertEqual(policy.captureSilenceTimeout, .fixed(seconds: 1.2))
    }

    func testAdaptivePauseSwitchesAfterMinimumSpeechDuration() {
        let policy = VoiceModePromptEndingPolicy(
            mode: .adaptivePause,
            fixedPauseSeconds: 1.2,
            adaptiveFastPauseSeconds: 0.6,
            adaptiveMinimumSpeechSeconds: 1.0,
            stopPhrase: "send it"
        )

        XCTAssertEqual(policy.silenceTimeout(afterSpeechDuration: 0.9), 1.2)
        XCTAssertEqual(policy.silenceTimeout(afterSpeechDuration: 1.0), 0.6)
        XCTAssertEqual(
            policy.captureSilenceTimeout,
            .adaptive(initialSeconds: 1.2, fastSeconds: 0.6, minimumSpeechSeconds: 1.0)
        )
    }

    func testAdaptivePausePresetOverridesCustomTiming() {
        let policy = VoiceModePromptEndingPolicy(
            mode: .adaptivePause,
            fixedPauseSeconds: 2.8,
            adaptivePausePreset: .fast,
            customAdaptiveFastPauseSeconds: 1.1,
            customAdaptiveMinimumSpeechSeconds: 2.5,
            stopPhrase: "send it"
        )

        XCTAssertEqual(policy.silenceTimeout(afterSpeechDuration: 0.79), 0.8)
        XCTAssertEqual(policy.silenceTimeout(afterSpeechDuration: 0.8), 0.45)
        XCTAssertEqual(
            policy.captureSilenceTimeout,
            .adaptive(initialSeconds: 0.8, fastSeconds: 0.45, minimumSpeechSeconds: 0.8)
        )
    }

    func testAdaptivePauseCustomPresetUsesCustomTiming() {
        let policy = VoiceModePromptEndingPolicy(
            mode: .adaptivePause,
            fixedPauseSeconds: 1.7,
            adaptivePausePreset: .custom,
            customAdaptiveFastPauseSeconds: 0.7,
            customAdaptiveMinimumSpeechSeconds: 1.4,
            stopPhrase: "send it"
        )

        XCTAssertEqual(policy.silenceTimeout(afterSpeechDuration: 1.39), 1.7)
        XCTAssertEqual(policy.silenceTimeout(afterSpeechDuration: 1.4), 0.7)
        XCTAssertEqual(
            policy.captureSilenceTimeout,
            .adaptive(initialSeconds: 1.7, fastSeconds: 0.7, minimumSpeechSeconds: 1.4)
        )
    }

    func testStopPhraseModeUsesFixedCapturePause() {
        let policy = VoiceModePromptEndingPolicy(
            mode: .stopPhrase,
            fixedPauseSeconds: 1.4,
            adaptiveFastPauseSeconds: 0.5,
            adaptiveMinimumSpeechSeconds: 1.0,
            stopPhrase: "send it"
        )

        XCTAssertEqual(policy.silenceTimeout(afterSpeechDuration: 3.0), 1.4)
        XCTAssertEqual(policy.captureSilenceTimeout, .fixed(seconds: 1.4))
    }

    func testStripsCustomTrailingStopPhrase() {
        let policy = VoiceModePromptEndingPolicy(
            mode: .stopPhrase,
            fixedPauseSeconds: 1.2,
            adaptiveFastPauseSeconds: 0.6,
            adaptiveMinimumSpeechSeconds: 1.0,
            stopPhrase: "send it"
        )

        XCTAssertEqual(
            policy.promptText(from: "summarize the meeting send it"),
            VoiceModePromptText(text: "summarize the meeting", endedByStopPhrase: true)
        )
        XCTAssertEqual(
            policy.promptText(from: "summarize the meeting, send it."),
            VoiceModePromptText(text: "summarize the meeting,", endedByStopPhrase: true)
        )
        XCTAssertEqual(
            policy.promptText(from: "summarize the meeting SEND   IT"),
            VoiceModePromptText(text: "summarize the meeting", endedByStopPhrase: true)
        )
    }

    func testDoesNotStripStopPhraseOutsideStopPhraseMode() {
        let policy = VoiceModePromptEndingPolicy(
            mode: .fixedPause,
            fixedPauseSeconds: 1.2,
            adaptiveFastPauseSeconds: 0.6,
            adaptiveMinimumSpeechSeconds: 1.0,
            stopPhrase: "send it"
        )

        XCTAssertEqual(
            policy.promptText(from: "summarize the meeting send it"),
            VoiceModePromptText(text: "summarize the meeting send it", endedByStopPhrase: false)
        )
    }

    func testDoesNotStripStopPhraseInTheMiddleOfPrompt() {
        let policy = VoiceModePromptEndingPolicy(
            mode: .stopPhrase,
            fixedPauseSeconds: 1.2,
            adaptiveFastPauseSeconds: 0.6,
            adaptiveMinimumSpeechSeconds: 1.0,
            stopPhrase: "send it"
        )

        XCTAssertEqual(
            policy.promptText(from: "send it to my notes app"),
            VoiceModePromptText(text: "send it to my notes app", endedByStopPhrase: false)
        )
    }

    func testEmptyStopPhraseIsIgnored() {
        let policy = VoiceModePromptEndingPolicy(
            mode: .stopPhrase,
            fixedPauseSeconds: 1.2,
            adaptiveFastPauseSeconds: 0.6,
            adaptiveMinimumSpeechSeconds: 1.0,
            stopPhrase: "   "
        )

        XCTAssertEqual(
            policy.promptText(from: "summarize this"),
            VoiceModePromptText(text: "summarize this", endedByStopPhrase: false)
        )
    }

    func testCaptureSilenceTimeoutUsesFastPauseOnlyAfterThreshold() {
        let timeout = VoiceGateCaptureSilenceTimeout.adaptive(
            initialSeconds: 1.2,
            fastSeconds: 0.6,
            minimumSpeechSeconds: 1.0
        )

        XCTAssertEqual(timeout.seconds(afterSpeechDuration: 0.99), 1.2)
        XCTAssertEqual(timeout.seconds(afterSpeechDuration: 1.0), 0.6)
    }
}
