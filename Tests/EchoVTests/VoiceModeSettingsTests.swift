import XCTest
@testable import EchoV

@MainActor
final class VoiceModeSettingsTests: XCTestCase {
    func testVoiceModeDefaultsToOffWithComputerWorkflowTiming() {
        let defaults = isolatedUserDefaults()
        let settings = AppSettings(userDefaults: defaults)

        XCTAssertFalse(settings.isVoiceModeEnabled)
        XCTAssertEqual(settings.voiceModeActivationHotkey, .defaultVoiceModeActivation)
        XCTAssertEqual(settings.voiceModeTextActivationHotkey, .defaultVoiceModeTextActivation)
        XCTAssertEqual(settings.stopHotkey, .defaultStop)
        XCTAssertEqual(settings.voiceModeResponsePauseSeconds, 1.2)
        XCTAssertEqual(settings.voiceModePromptEndingMode, .fixedPause)
        XCTAssertEqual(settings.voiceModeAdaptivePausePreset, .balanced)
        XCTAssertEqual(settings.voiceModeAdaptiveFastPauseSeconds, 0.6)
        XCTAssertEqual(settings.voiceModeAdaptiveMinimumSpeechSeconds, 1.0)
        XCTAssertEqual(settings.voiceModeStopPhrase, "go ahead")
        XCTAssertEqual(settings.voiceModeNoSpeechTimeoutSeconds, 8.0)
        XCTAssertEqual(settings.voiceModeResponseBackend, .localLlama)
        XCTAssertTrue(settings.isLocalVoiceModePromptPreviewEnabled)
        XCTAssertTrue(settings.isCloudVoiceModePromptPreviewEnabled)
        XCTAssertTrue(settings.isVoiceModeHUDEnabled)
        XCTAssertTrue(settings.isAssistantConfirmationSoundEnabled)
        XCTAssertEqual(settings.assistantConfirmationSoundStyle, .starship)
        XCTAssertTrue(settings.textResponseStreamsReplies)
        XCTAssertFalse(settings.textResponseShowsReasoning)
        XCTAssertEqual(settings.voiceModeCloudBaseURL, "")
        XCTAssertEqual(settings.voiceModeCloudModel, "")
        XCTAssertNil(settings.voiceModeCloudContextWindowTokens)
        XCTAssertEqual(settings.voiceModeKokoroVoiceIdentifier, KokoroVoiceCatalog.defaultVoiceID)
        XCTAssertEqual(settings.voiceModeKokoroSpeed, 1.0)
    }

    func testVoiceModeSliderValuesAreClampedWhenLoaded() {
        let defaults = isolatedUserDefaults()
        defaults.set(9.0, forKey: "settings.voiceModeResponsePauseSeconds")
        defaults.set(0.1, forKey: "settings.voiceModeAdaptiveFastPauseSeconds")
        defaults.set(99.0, forKey: "settings.voiceModeAdaptiveMinimumSpeechSeconds")
        defaults.set(100.0, forKey: "settings.voiceModeNoSpeechTimeoutSeconds")
        defaults.set(0.1, forKey: "settings.voiceModeKokoroSpeed")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertEqual(settings.voiceModeResponsePauseSeconds, 3.0)
        XCTAssertEqual(settings.voiceModeAdaptiveFastPauseSeconds, 0.4)
        XCTAssertEqual(settings.voiceModeAdaptiveMinimumSpeechSeconds, 3.0)
        XCTAssertEqual(settings.voiceModeNoSpeechTimeoutSeconds, 15.0)
        XCTAssertEqual(settings.voiceModeKokoroSpeed, 0.5)
    }

    func testVoiceModeLoadsPromptEndingFields() {
        let defaults = isolatedUserDefaults()
        defaults.set(VoiceModePromptEndingMode.stopPhrase.rawValue, forKey: "settings.voiceModePromptEndingMode")
        defaults.set(VoiceModeAdaptivePausePreset.fast.rawValue, forKey: "settings.voiceModeAdaptivePausePreset")
        defaults.set(0.8, forKey: "settings.voiceModeAdaptiveFastPauseSeconds")
        defaults.set(1.5, forKey: "settings.voiceModeAdaptiveMinimumSpeechSeconds")
        defaults.set("  send   now  ", forKey: "settings.voiceModeStopPhrase")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertEqual(settings.voiceModePromptEndingMode, .stopPhrase)
        XCTAssertEqual(settings.voiceModeAdaptivePausePreset, .fast)
        XCTAssertEqual(settings.voiceModeAdaptiveFastPauseSeconds, 0.8)
        XCTAssertEqual(settings.voiceModeAdaptiveMinimumSpeechSeconds, 1.5)
        XCTAssertEqual(settings.voiceModeStopPhrase, "send now")
    }

    func testVoiceModePersistsAdaptivePausePreset() {
        let defaults = isolatedUserDefaults()
        let settings = AppSettings(userDefaults: defaults)

        settings.voiceModeAdaptivePausePreset = .relaxed

        let reloadedSettings = AppSettings(userDefaults: defaults)
        XCTAssertEqual(reloadedSettings.voiceModeAdaptivePausePreset, .relaxed)
    }

    func testResetHotkeysRestoresVoiceModeTextHotkey() {
        let defaults = isolatedUserDefaults()
        let settings = AppSettings(userDefaults: defaults)

        settings.voiceModeActivationHotkey = nil
        settings.voiceModeTextActivationHotkey = nil
        settings.stopHotkey = nil
        settings.resetHotkeysToDefaults()

        XCTAssertEqual(settings.voiceModeActivationHotkey, .defaultVoiceModeActivation)
        XCTAssertEqual(settings.voiceModeTextActivationHotkey, .defaultVoiceModeTextActivation)
        XCTAssertEqual(settings.stopHotkey, .defaultStop)
    }

    func testVoiceModeLoadsCloudResponseProviderFields() {
        let defaults = isolatedUserDefaults()
        defaults.set(VoiceModeResponseBackend.openAICompatibleCloud.rawValue, forKey: "settings.voiceModeResponseBackend")
        defaults.set(false, forKey: "settings.isLocalVoiceModePromptPreviewEnabled")
        defaults.set(true, forKey: "settings.isCloudVoiceModePromptPreviewEnabled")
        defaults.set(false, forKey: "settings.isVoiceModeHUDEnabled")
        defaults.set(false, forKey: "settings.isAssistantConfirmationSoundEnabled")
        defaults.set(AssistantConfirmationSoundStyle.terminal.rawValue, forKey: "settings.assistantConfirmationSoundStyle")
        defaults.set(false, forKey: "settings.textResponseStreamsReplies")
        defaults.set(true, forKey: "settings.textResponseShowsReasoning")
        defaults.set("https://api.example.com/v1", forKey: "settings.voiceModeCloudBaseURL")
        defaults.set("example-model", forKey: "settings.voiceModeCloudModel")
        defaults.set(128_000, forKey: "settings.voiceModeCloudContextWindowTokens")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertEqual(settings.voiceModeResponseBackend, .openAICompatibleCloud)
        XCTAssertFalse(settings.isLocalVoiceModePromptPreviewEnabled)
        XCTAssertTrue(settings.isCloudVoiceModePromptPreviewEnabled)
        XCTAssertFalse(settings.isVoiceModeHUDEnabled)
        XCTAssertFalse(settings.isAssistantConfirmationSoundEnabled)
        XCTAssertEqual(settings.assistantConfirmationSoundStyle, .terminal)
        XCTAssertFalse(settings.textResponseStreamsReplies)
        XCTAssertTrue(settings.textResponseShowsReasoning)
        XCTAssertEqual(settings.voiceModeCloudBaseURL, "https://api.example.com/v1")
        XCTAssertEqual(settings.voiceModeCloudModel, "example-model")
        XCTAssertEqual(settings.voiceModeCloudContextWindowTokens, 128_000)
    }

    func testVoiceModePromptPreviewMigratesLegacySingleSettingWithoutDisablingCloudDefault() {
        let defaults = isolatedUserDefaults()
        defaults.set(false, forKey: "settings.isVoiceModePromptPreviewEnabled")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertFalse(settings.isLocalVoiceModePromptPreviewEnabled)
        XCTAssertTrue(settings.isCloudVoiceModePromptPreviewEnabled)
    }

    func testVoiceModeCloudContextWindowIsClamped() {
        let defaults = isolatedUserDefaults()
        defaults.set(100, forKey: "settings.voiceModeCloudContextWindowTokens")

        let settings = AppSettings(userDefaults: defaults)
        XCTAssertEqual(settings.voiceModeCloudContextWindowTokens, AppSettings.cloudContextWindowTokenRange.lowerBound)

        settings.voiceModeCloudContextWindowTokens = 9_000_000
        XCTAssertEqual(settings.voiceModeCloudContextWindowTokens, AppSettings.cloudContextWindowTokenRange.upperBound)
    }

    func testVoiceModeCloudContextWindowCanBeCleared() {
        let defaults = isolatedUserDefaults()
        defaults.set(128_000, forKey: "settings.voiceModeCloudContextWindowTokens")

        let settings = AppSettings(userDefaults: defaults)
        settings.voiceModeCloudContextWindowTokens = nil

        XCTAssertNil(settings.voiceModeCloudContextWindowTokens)
        XCTAssertNil(defaults.object(forKey: "settings.voiceModeCloudContextWindowTokens"))
    }

    func testVoiceGuardDefaultsToOffWithAllTargetsSelected() {
        let defaults = isolatedUserDefaults()
        let settings = AppSettings(userDefaults: defaults)

        XCTAssertFalse(settings.isVoiceGuardEnabled)
        XCTAssertTrue(settings.isVoiceGuardEnabledForVoiceGate)
        XCTAssertTrue(settings.isVoiceGuardEnabledForVoiceModeCommands)
        XCTAssertTrue(settings.isVoiceGuardEnabledForVoiceModeRequests)
    }

    func testVoiceGuardMigratesLegacyVoiceGateSpeakerMatchMaster() {
        let defaults = isolatedUserDefaults()
        defaults.set(true, forKey: "settings.isVoiceGateSpeakerMatchEnabled")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertTrue(settings.isVoiceGuardEnabled)
        XCTAssertTrue(settings.isVoiceGuardEnabledForVoiceGate)
        XCTAssertTrue(settings.isVoiceGuardEnabledForVoiceModeCommands)
        XCTAssertTrue(settings.isVoiceGuardEnabledForVoiceModeRequests)
    }

    func testVoiceGuardNewMasterValueWinsOverLegacyMigrationValue() {
        let defaults = isolatedUserDefaults()
        defaults.set(true, forKey: "settings.isVoiceGateSpeakerMatchEnabled")
        defaults.set(false, forKey: "settings.isVoiceGuardEnabled")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertFalse(settings.isVoiceGuardEnabled)
    }

    func testVoiceGuardTargetSelectionsPersistIndependentlyFromMaster() {
        let defaults = isolatedUserDefaults()
        let settings = AppSettings(userDefaults: defaults)

        settings.isVoiceGuardEnabledForVoiceGate = true
        settings.isVoiceGuardEnabledForVoiceModeCommands = false
        settings.isVoiceGuardEnabledForVoiceModeRequests = true
        settings.isVoiceGuardEnabled = false
        settings.isVoiceGuardEnabled = true

        let reloadedSettings = AppSettings(userDefaults: defaults)
        XCTAssertTrue(reloadedSettings.isVoiceGuardEnabled)
        XCTAssertTrue(reloadedSettings.isVoiceGuardEnabledForVoiceGate)
        XCTAssertFalse(reloadedSettings.isVoiceGuardEnabledForVoiceModeCommands)
        XCTAssertTrue(reloadedSettings.isVoiceGuardEnabledForVoiceModeRequests)
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "EchoVTests.VoiceModeSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
