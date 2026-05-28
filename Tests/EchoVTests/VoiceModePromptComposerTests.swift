import XCTest
@testable import EchoV

final class VoiceModePromptComposerTests: XCTestCase {
    func testUsesPlainPromptWithoutSelectedText() {
        XCTAssertEqual(
            VoiceModePromptComposer.compose(userPrompt: "  summarize this  ", selectedText: nil),
            "summarize this"
        )
    }

    func testPrefixesSelectedTextBeforePrompt() {
        XCTAssertEqual(
            VoiceModePromptComposer.compose(
                userPrompt: "  summarize this  ",
                selectedText: "  First paragraph.\nSecond paragraph.  "
            ),
            """
            Background text:
            First paragraph.
            Second paragraph.

            What I want:
            summarize this
            """
        )
    }

    func testSelectionOnlyFallsBackToSelection() {
        XCTAssertEqual(
            VoiceModePromptComposer.compose(userPrompt: "   ", selectedText: "  Clean me  "),
            """
            Background text:
            Clean me
            """
        )
    }
}
