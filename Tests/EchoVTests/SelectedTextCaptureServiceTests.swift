import XCTest
@testable import EchoV

final class SelectedTextCaptureServiceTests: XCTestCase {
    func testZeroLengthSelectionRangeWinsOverTextLikeValue() {
        let state = AccessibilitySelectedTextInspector.selectionState(
            selectedText: "current line copied by editor",
            selectedTextWasReadable: true,
            selectedRangeLengths: [0],
            selectedRangeLengthsWereReadable: true,
            clipboardFallbackAllowed: false
        )

        XCTAssertEqual(state, .noSelection)
    }

    func testNonEmptySelectionUsesReadableSelectedText() {
        let state = AccessibilitySelectedTextInspector.selectionState(
            selectedText: "  selected text  ",
            selectedTextWasReadable: true,
            selectedRangeLengths: [13],
            selectedRangeLengthsWereReadable: true,
            clipboardFallbackAllowed: false
        )

        XCTAssertEqual(state, .selectedText("selected text"))
    }

    func testNonEmptySelectionRangeFallsBackToClipboardWhenSelectedTextIsUnavailable() {
        let state = AccessibilitySelectedTextInspector.selectionState(
            selectedText: nil,
            selectedTextWasReadable: false,
            selectedRangeLengths: [4],
            selectedRangeLengthsWereReadable: true,
            clipboardFallbackAllowed: true
        )

        XCTAssertEqual(state, .selectionPresent)
    }

    func testReadableEmptySelectedTextMeansNoSelection() {
        let state = AccessibilitySelectedTextInspector.selectionState(
            selectedText: "  ",
            selectedTextWasReadable: true,
            selectedRangeLengths: nil,
            selectedRangeLengthsWereReadable: false,
            clipboardFallbackAllowed: true
        )

        XCTAssertEqual(state, .noSelection)
    }

    func testClipboardFallbackIsDisabledForJetBrainsAppsWhenSelectionIsUnknown() {
        XCTAssertFalse(AccessibilitySelectedTextInspector.clipboardFallbackAllowed(for: "com.jetbrains.intellij"))
    }

    func testClipboardFallbackIsAllowedForUnclassifiedAppsWhenSelectionIsUnknown() {
        XCTAssertTrue(AccessibilitySelectedTextInspector.clipboardFallbackAllowed(for: "org.mozilla.firefox"))
    }
}
