import AppKit
import SwiftUI
import XCTest
@testable import EchoV

final class MarkdownMessageRendererTests: XCTestCase {
    func testParsesHeadingsThroughLevelSix() {
        let blocks = MarkdownBlock.parse(
            """
            # Level one
            ###### Level six
            ####### Not a heading
            """
        )

        XCTAssertEqual(blocks, [
            MarkdownBlock(kind: .heading(level: 1), text: "Level one"),
            MarkdownBlock(kind: .heading(level: 6), text: "Level six"),
            MarkdownBlock(kind: .paragraph, text: "####### Not a heading")
        ])
    }

    func testParsesBulletMarkersAndNumberedLines() {
        let blocks = MarkdownBlock.parse(
            """
            - dash
            * star
            \u{2022} bullet
            12. numbered
            """
        )

        XCTAssertEqual(blocks, [
            MarkdownBlock(kind: .bullet, text: "dash"),
            MarkdownBlock(kind: .bullet, text: "star"),
            MarkdownBlock(kind: .bullet, text: "bullet"),
            MarkdownBlock(kind: .bullet, text: "numbered")
        ])
    }

    func testPreservesFencedCodeWhitespace() {
        let blocks = MarkdownBlock.parse(
            """
            Before

            ```swift
              let value = 1
                print(value)
            ```

            After
            """
        )

        XCTAssertEqual(blocks, [
            MarkdownBlock(kind: .paragraph, text: "Before"),
            MarkdownBlock(kind: .code, text: "  let value = 1\n    print(value)"),
            MarkdownBlock(kind: .paragraph, text: "After")
        ])
    }

    func testUnclosedFencedCodeStillRendersContent() {
        let blocks = MarkdownBlock.parse(
            """
            ```text
            first
              second
            """
        )

        XCTAssertEqual(blocks, [
            MarkdownBlock(kind: .code, text: "first\n  second")
        ])
    }

    func testFormatsSimplePipeTablesAsAlignedText() {
        let blocks = MarkdownBlock.parse(
            """
            | Name | Value |
            | --- | --- |
            | Alpha | 1 |
            | Beta | 22 |
            """
        )

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.kind, .table)

        let lines = blocks.first?.text.components(separatedBy: "\n") ?? []
        XCTAssertEqual(lines, [
            "Name   Value",
            "Alpha  1    ",
            "Beta   22   "
        ])
    }

    func testMalformedTablesFallBackToReadableParagraphs() {
        let blocks = MarkdownBlock.parse("Path | Notes")

        XCTAssertEqual(blocks, [
            MarkdownBlock(kind: .paragraph, text: "Path | Notes")
        ])
    }

    @MainActor
    func testRendererAppliesLinksAndFilePathHighlighting() {
        let attributed = MarkdownAttributedStringRenderer.attributedString(
            for: "Open [docs](https://example.com) and https://swift.org then EchoV/App/AppContainer.swift:42"
        )
        let string = attributed.string as NSString

        let markdownLinkRange = string.range(of: "docs")
        XCTAssertEqual(
            attributed.attribute(.link, at: markdownLinkRange.location, effectiveRange: nil) as? String,
            "https://example.com"
        )

        let detectedLinkRange = string.range(of: "https://swift.org")
        let detectedLink = attributed.attribute(.link, at: detectedLinkRange.location, effectiveRange: nil) as? URL
        XCTAssertEqual(detectedLink?.absoluteString, "https://swift.org")

        let filePathRange = string.range(of: "EchoV/App/AppContainer.swift:42")
        let filePathFont = attributed.attribute(.font, at: filePathRange.location, effectiveRange: nil) as? NSFont
        XCTAssertTrue(filePathFont?.fontDescriptor.symbolicTraits.contains(.monoSpace) == true)
        XCTAssertNil(attributed.attribute(.link, at: filePathRange.location, effectiveRange: nil))
    }

    @MainActor
    func testMarkdownMessageViewHostsSelectableTransparentWidthTrackingTextView() {
        let content = """
        # Summary

        - First wrapped item with enough content to need multiple visual lines in a narrow chat bubble.
        - Second item with **bold**, `code`, https://example.com, and EchoV/TextResponse/TextResponseSessionView.swift:42.

        | Key | Value |
        | --- | --- |
        | Mode | Text response |

        ```swift
        let value = "kept"
          print(value)
        ```
        """
        let host = NSHostingView(rootView: MarkdownMessageView(content: content).frame(width: 360))
        host.frame = NSRect(x: 0, y: 0, width: 360, height: 500)

        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()

        let textView = host.firstDescendant(ofType: NSTextView.self)
        XCTAssertNotNil(textView)
        XCTAssertEqual(textView?.string.contains("Summary"), true)
        XCTAssertEqual(textView?.isEditable, false)
        XCTAssertEqual(textView?.isSelectable, true)
        XCTAssertEqual(textView?.drawsBackground, false)
        XCTAssertEqual(textView?.backgroundColor, .clear)
        XCTAssertEqual(textView?.textContainer?.widthTracksTextView, true)
        XCTAssertEqual(textView?.textContainer?.lineFragmentPadding, 0)
    }
}

private extension NSView {
    func firstDescendant<ViewType: NSView>(ofType type: ViewType.Type) -> ViewType? {
        for subview in subviews {
            if let match = subview as? ViewType {
                return match
            }
            if let match = subview.firstDescendant(ofType: type) {
                return match
            }
        }

        return nil
    }
}
