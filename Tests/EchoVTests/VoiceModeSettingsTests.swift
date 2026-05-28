import XCTest
@testable import EchoV

@MainActor
final class VoiceModeSettingsTests: XCTestCase {
    func testVoiceModeDefaultsToOffWithComputerWorkflowTiming() {
        let defaults = isolatedUserDefaults()
        let settings = AppSettings(userDefaults: defaults)

        XCTAssertFalse(settings.isVoiceModeEnabled)
        XCTAssertEqual(settings.voiceModeActivationHotkey, .defaultVoiceModeActivation)
        XCTAssertEqual(settings.voiceModeResponsePauseSeconds, 1.2)
        XCTAssertEqual(settings.voiceModeNoSpeechTimeoutSeconds, 8.0)
        XCTAssertEqual(settings.voiceModeResponseBackend, .localLlama)
        XCTAssertEqual(settings.voiceModeResponseDelivery, .spoken)
        XCTAssertTrue(settings.textResponseStreamsReplies)
        XCTAssertFalse(settings.textResponseShowsReasoning)
        XCTAssertEqual(settings.voiceModeCloudBaseURL, "")
        XCTAssertEqual(settings.voiceModeCloudModel, "")
        XCTAssertEqual(settings.voiceModeKokoroVoiceIdentifier, KokoroVoiceCatalog.defaultVoiceID)
        XCTAssertEqual(settings.voiceModeKokoroSpeed, 1.0)
    }

    func testVoiceModeSliderValuesAreClampedWhenLoaded() {
        let defaults = isolatedUserDefaults()
        defaults.set(9.0, forKey: "settings.voiceModeResponsePauseSeconds")
        defaults.set(100.0, forKey: "settings.voiceModeNoSpeechTimeoutSeconds")
        defaults.set(0.1, forKey: "settings.voiceModeKokoroSpeed")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertEqual(settings.voiceModeResponsePauseSeconds, 3.0)
        XCTAssertEqual(settings.voiceModeNoSpeechTimeoutSeconds, 15.0)
        XCTAssertEqual(settings.voiceModeKokoroSpeed, 0.5)
    }

    func testVoiceModeLoadsCloudResponseProviderFields() {
        let defaults = isolatedUserDefaults()
        defaults.set(VoiceModeResponseBackend.openAICompatibleCloud.rawValue, forKey: "settings.voiceModeResponseBackend")
        defaults.set(VoiceModeResponseDelivery.textResponse.rawValue, forKey: "settings.voiceModeResponseDelivery")
        defaults.set(false, forKey: "settings.textResponseStreamsReplies")
        defaults.set(true, forKey: "settings.textResponseShowsReasoning")
        defaults.set("https://api.example.com/v1", forKey: "settings.voiceModeCloudBaseURL")
        defaults.set("example-model", forKey: "settings.voiceModeCloudModel")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertEqual(settings.voiceModeResponseBackend, .openAICompatibleCloud)
        XCTAssertEqual(settings.voiceModeResponseDelivery, .textResponse)
        XCTAssertFalse(settings.textResponseStreamsReplies)
        XCTAssertTrue(settings.textResponseShowsReasoning)
        XCTAssertEqual(settings.voiceModeCloudBaseURL, "https://api.example.com/v1")
        XCTAssertEqual(settings.voiceModeCloudModel, "example-model")
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "EchoVTests.VoiceModeSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
