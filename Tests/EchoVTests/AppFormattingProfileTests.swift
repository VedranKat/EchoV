import XCTest
@testable import EchoV

final class AppFormattingProfileTests: XCTestCase {
    func testMapsKnownBundleIdentifiersToProfiles() {
        XCTAssertEqual(
            AppFormattingProfile.profile(
                for: TargetAppContext(localizedName: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap")
            ),
            .chat
        )
        XCTAssertEqual(
            AppFormattingProfile.profile(
                for: TargetAppContext(localizedName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
            ),
            .code
        )
        XCTAssertEqual(
            AppFormattingProfile.profile(
                for: TargetAppContext(localizedName: "Terminal", bundleIdentifier: "com.apple.Terminal")
            ),
            .terminal
        )
        XCTAssertEqual(
            AppFormattingProfile.profile(
                for: TargetAppContext(localizedName: "Mail", bundleIdentifier: "com.apple.mail")
            ),
            .email
        )
    }

    func testUnknownAppsUseGeneralProfile() {
        XCTAssertEqual(
            AppFormattingProfile.profile(
                for: TargetAppContext(localizedName: "Unknown", bundleIdentifier: "example.app")
            ),
            .general
        )
    }

    func testTerminalPromptInstructionMentionsSpokenCommandPunctuation() {
        let instruction = AppFormattingProfile.terminal.promptInstruction

        XCTAssertEqual(instruction.contains("Output shell text, not prose"), true)
        XCTAssertEqual(instruction.contains("\"dash dash\" to --"), true)
        XCTAssertEqual(instruction.contains("\"new line\" to line breaks"), true)
    }
}
