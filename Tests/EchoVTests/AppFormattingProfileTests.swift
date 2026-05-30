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
}
