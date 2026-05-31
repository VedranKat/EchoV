import XCTest
@testable import EchoV

@MainActor
final class LiveSubtitleSettingsTests: XCTestCase {
    func testLiveSubtitleDefaultsAreConservative() {
        let defaults = isolatedUserDefaults()
        let settings = AppSettings(userDefaults: defaults)

        XCTAssertFalse(settings.isLiveSubtitlesEnabled)
        XCTAssertEqual(settings.liveSubtitleHotkey, .defaultLiveSubtitles)
        XCTAssertNil(settings.selectedLiveSubtitleAudioDeviceID)
        XCTAssertEqual(settings.liveSubtitleMode, .rawCaptions)
        XCTAssertEqual(settings.liveSubtitleTargetLanguage, "English")
        XCTAssertEqual(settings.liveSubtitleChunkPreset, .balanced)
        XCTAssertTrue(settings.liveSubtitleShowsRawWhileProcessing)
        XCTAssertEqual(settings.liveSubtitleTextSize, 28)
        XCTAssertEqual(settings.liveSubtitleMaxLines, 2)
        XCTAssertEqual(settings.liveSubtitleBottomMargin, 56)
        XCTAssertEqual(settings.liveSubtitleHoldSeconds, 2.2)
    }

    func testLiveSubtitleCustomValuesAreClampedWhenLoaded() {
        let defaults = isolatedUserDefaults()
        defaults.set(100.0, forKey: "settings.liveSubtitleMaxChunkSeconds")
        defaults.set(0.01, forKey: "settings.liveSubtitleSilenceTimeoutSeconds")
        defaults.set(99.0, forKey: "settings.liveSubtitleMinimumSpeechSeconds")
        defaults.set(10.0, forKey: "settings.liveSubtitlePreRollSeconds")
        defaults.set(10.0, forKey: "settings.liveSubtitleOverlapSeconds")
        defaults.set(2.0, forKey: "settings.liveSubtitleTextSize")
        defaults.set(99, forKey: "settings.liveSubtitleMaxLines")
        defaults.set(1.0, forKey: "settings.liveSubtitleBottomMargin")
        defaults.set(100.0, forKey: "settings.liveSubtitleHoldSeconds")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertEqual(settings.liveSubtitleMaxChunkSeconds, 12.0)
        XCTAssertEqual(settings.liveSubtitleSilenceTimeoutSeconds, 0.25)
        XCTAssertEqual(settings.liveSubtitleMinimumSpeechSeconds, 1.5)
        XCTAssertEqual(settings.liveSubtitlePreRollSeconds, 1.0)
        XCTAssertEqual(settings.liveSubtitleOverlapSeconds, 0.75)
        XCTAssertEqual(settings.liveSubtitleTextSize, 18)
        XCTAssertEqual(settings.liveSubtitleMaxLines, 3)
        XCTAssertEqual(settings.liveSubtitleBottomMargin, 20)
        XCTAssertEqual(settings.liveSubtitleHoldSeconds, 8.0)
    }

    func testPresetConfigurationIgnoresCustomValuesUntilCustomPresetIsSelected() {
        let defaults = isolatedUserDefaults()
        let settings = AppSettings(userDefaults: defaults)
        settings.liveSubtitleMaxChunkSeconds = 9.0
        settings.liveSubtitleSilenceTimeoutSeconds = 2.0

        settings.liveSubtitleChunkPreset = .fast
        XCTAssertEqual(settings.liveSubtitleChunkConfiguration.maxChunkSeconds, LiveSubtitleChunkPreset.fast.defaults.maxChunkSeconds)
        XCTAssertEqual(settings.liveSubtitleChunkConfiguration.silenceTimeoutSeconds, LiveSubtitleChunkPreset.fast.defaults.silenceTimeoutSeconds)

        settings.liveSubtitleChunkPreset = .custom
        XCTAssertEqual(settings.liveSubtitleChunkConfiguration.maxChunkSeconds, 9.0)
        XCTAssertEqual(settings.liveSubtitleChunkConfiguration.silenceTimeoutSeconds, 2.0)
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "EchoVTests.LiveSubtitleSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
