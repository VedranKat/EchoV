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
            Selected text:
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
            Selected text:
            Clean me
            """
        )
    }

    func testTruncatesVeryLargeSelectionWithNotice() {
        let selection = String(repeating: "a", count: 24_100)
        let composed = VoiceModePromptComposer.compose(userPrompt: "summarize", selectedText: selection)

        XCTAssertTrue(composed.hasPrefix("Selected text:\n"))
        XCTAssertTrue(composed.contains("[Selected text truncated by EchoV because it was too long.]"))
        XCTAssertTrue(composed.contains("\n\nWhat I want:\nsummarize"))
    }
}
