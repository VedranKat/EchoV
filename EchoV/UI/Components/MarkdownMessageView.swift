import AppKit
import SwiftUI

struct MarkdownMessageView: View {
    let content: String
    var style: MarkdownMessageTextStyle = .primary
    @State private var height: CGFloat = 28

    var body: some View {
        StructuredSelectableTextView(content: content, style: style, calculatedHeight: $height)
            .frame(height: height)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MarkdownMessageTextStyle: Equatable, Sendable {
    enum Tone: Equatable, Sendable {
        case primary
        case secondary
    }

    var tone: Tone
    var baseFontSize: CGFloat

    static let primary = MarkdownMessageTextStyle(tone: .primary, baseFontSize: 14.5)
    static let secondary = MarkdownMessageTextStyle(tone: .secondary, baseFontSize: 13)

    var textColor: NSColor {
        switch tone {
        case .primary:
            return .labelColor
        case .secondary:
            return .secondaryLabelColor
        }
    }

    var linkColor: NSColor {
        .controlAccentColor
    }

    var codeBackgroundColor: NSColor {
        switch tone {
        case .primary:
            return NSColor.textBackgroundColor.withAlphaComponent(0.55)
        case .secondary:
            return NSColor.textBackgroundColor.withAlphaComponent(0.40)
        }
    }

    var tableBackgroundColor: NSColor {
        switch tone {
        case .primary:
            return NSColor.textBackgroundColor.withAlphaComponent(0.45)
        case .secondary:
            return NSColor.textBackgroundColor.withAlphaComponent(0.32)
        }
    }
}

private struct StructuredSelectableTextView: NSViewRepresentable {
    let content: String
    let style: MarkdownMessageTextStyle
    @Binding var calculatedHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> SelectableTextContainerView {
        let view = SelectableTextContainerView()
        view.textView.isEditable = false
        view.textView.isSelectable = true
        view.textView.drawsBackground = false
        view.textView.backgroundColor = .clear
        view.textView.linkTextAttributes = [
            .foregroundColor: style.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        view.textView.textContainerInset = .zero
        view.textView.textContainer?.lineFragmentPadding = 0
        view.textView.isVerticallyResizable = true
        view.textView.isHorizontallyResizable = false
        view.textView.autoresizingMask = [.width]
        view.textView.textContainer?.widthTracksTextView = true
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.onHeightChanged = { height in
            context.coordinator.updateHeight(height)
        }
        context.coordinator.containerView = view
        context.coordinator.updateContent(content, style: style)
        return view
    }

    func updateNSView(_ view: SelectableTextContainerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.containerView = view
        context.coordinator.updateContent(content, style: style)
    }

    @MainActor
    final class Coordinator {
        var parent: StructuredSelectableTextView
        weak var containerView: SelectableTextContainerView?
        private var renderedContent = ""
        private var renderedStyle: MarkdownMessageTextStyle?

        init(parent: StructuredSelectableTextView) {
            self.parent = parent
        }

        func updateContent(_ content: String, style: MarkdownMessageTextStyle) {
            if renderedContent != content || renderedStyle != style {
                containerView?.textView.textStorage?.setAttributedString(
                    MarkdownAttributedStringRenderer.attributedString(for: content, style: style)
                )
                renderedContent = content
                renderedStyle = style
            }
            containerView?.recalculateHeight()
            scheduleRecalculation()
        }

        func updateHeight(_ height: CGFloat) {
            guard abs(parent.calculatedHeight - height) > 0.5 else { return }
            parent.calculatedHeight = height
        }

        private func scheduleRecalculation() {
            DispatchQueue.main.async { [weak self] in
                self?.containerView?.forceLayoutRecalculation()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.containerView?.forceLayoutRecalculation()
            }
        }
    }
}

enum MarkdownAttributedStringRenderer {
    static func attributedString(
        for content: String,
        style: MarkdownMessageTextStyle = .primary
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()

        for block in MarkdownBlock.parse(content) {
            if output.length > 0 {
                output.append(NSAttributedString(string: "\n"))
            }
            output.append(attributedBlock(block, style: style))
        }

        return output
    }

    private static func attributedBlock(_ block: MarkdownBlock, style: MarkdownMessageTextStyle) -> NSAttributedString {
        switch block.kind {
        case .heading(let level):
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = level <= 2 ? 8 : 6
            paragraphStyle.lineSpacing = 2
            let font = headingFont(for: level, baseSize: style.baseFontSize)
            return attributedInlineMarkdown(
                block.text,
                baseFont: font,
                boldFont: font,
                paragraphStyle: paragraphStyle,
                style: style
            )

        case .paragraph:
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 8
            paragraphStyle.lineSpacing = 2
            let font = NSFont.systemFont(ofSize: style.baseFontSize)
            return attributedInlineMarkdown(
                block.text,
                baseFont: font,
                boldFont: NSFont.systemFont(ofSize: font.pointSize, weight: .semibold),
                paragraphStyle: paragraphStyle,
                style: style
            )

        case .bullet:
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 5
            paragraphStyle.lineSpacing = 2
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.headIndent = 18
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: 18)]
            let font = NSFont.systemFont(ofSize: style.baseFontSize)
            return attributedInlineMarkdown(
                "\u{2022}\t\(block.text)",
                baseFont: font,
                boldFont: NSFont.systemFont(ofSize: font.pointSize, weight: .semibold),
                paragraphStyle: paragraphStyle,
                style: style
            )

        case .code:
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 8
            paragraphStyle.lineSpacing = 1
            return NSAttributedString(
                string: block.text,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: max(style.baseFontSize - 1, 11), weight: .regular),
                    .foregroundColor: style.textColor,
                    .backgroundColor: style.codeBackgroundColor,
                    .paragraphStyle: paragraphStyle
                ]
            )

        case .table:
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 8
            paragraphStyle.lineSpacing = 1.4
            return NSAttributedString(
                string: block.text,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: max(style.baseFontSize - 1.5, 11), weight: .regular),
                    .foregroundColor: style.textColor,
                    .backgroundColor: style.tableBackgroundColor,
                    .paragraphStyle: paragraphStyle
                ]
            )
        }
    }

    private static func headingFont(for level: Int, baseSize: CGFloat) -> NSFont {
        switch level {
        case 1:
            return .systemFont(ofSize: baseSize + 2.5, weight: .semibold)
        case 2:
            return .systemFont(ofSize: baseSize + 1, weight: .semibold)
        case 3:
            return .systemFont(ofSize: baseSize + 0.3, weight: .semibold)
        default:
            return .systemFont(ofSize: baseSize, weight: .semibold)
        }
    }

    private static func attributedInlineMarkdown(
        _ text: String,
        baseFont: NSFont,
        boldFont: NSFont,
        paragraphStyle: NSParagraphStyle,
        style: MarkdownMessageTextStyle
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()
        var index = text.startIndex
        var isBold = false
        var isCode = false
        var buffer = ""

        func flush() {
            guard !buffer.isEmpty else { return }
            let font = isCode
                ? NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular)
                : (isBold ? boldFont : baseFont)
            append(buffer, font: font)
            buffer.removeAll()
        }

        func append(_ string: String, font: NSFont, link: String? = nil) {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: style.textColor,
                .paragraphStyle: paragraphStyle
            ]
            if let link {
                attributes[.link] = link
                attributes[.foregroundColor] = style.linkColor
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            output.append(NSAttributedString(string: string, attributes: attributes))
        }

        while index < text.endIndex {
            if text[index...].hasPrefix("**") {
                flush()
                isBold.toggle()
                index = text.index(index, offsetBy: 2)
                continue
            }
            if let markdownLink = markdownLink(in: text, at: index) {
                flush()
                append(markdownLink.label, font: isBold ? boldFont : baseFont, link: markdownLink.destination)
                index = markdownLink.nextIndex
                continue
            }
            if text[index] == "`" {
                flush()
                isCode.toggle()
                index = text.index(after: index)
                continue
            }
            if text[index] == "*" || text[index] == "_" {
                index = text.index(after: index)
                continue
            }

            buffer.append(text[index])
            index = text.index(after: index)
        }

        flush()
        applyDetectedLinks(to: output, style: style)
        applyFilePathHighlights(to: output, style: style, pointSize: baseFont.pointSize)
        return output
    }

    private static func markdownLink(
        in text: String,
        at index: String.Index
    ) -> (label: String, destination: String, nextIndex: String.Index)? {
        guard text[index] == "[" else { return nil }
        let labelStart = text.index(after: index)
        guard let labelEnd = text[labelStart...].firstIndex(of: "]") else { return nil }
        let openParen = text.index(after: labelEnd)
        guard openParen < text.endIndex, text[openParen] == "(" else { return nil }
        let destinationStart = text.index(after: openParen)
        guard let destinationEnd = text[destinationStart...].firstIndex(of: ")") else { return nil }
        let label = String(text[labelStart..<labelEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = String(text[destinationStart..<destinationEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, !destination.isEmpty else { return nil }
        return (label, destination, text.index(after: destinationEnd))
    }

    private static func applyDetectedLinks(to attributedString: NSMutableAttributedString, style: MarkdownMessageTextStyle) {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return }
        let fullRange = NSRange(location: 0, length: attributedString.length)
        detector.enumerateMatches(in: attributedString.string, range: fullRange) { match, _, _ in
            guard let match, let url = match.url else { return }
            attributedString.addAttributes([
                .link: url,
                .foregroundColor: style.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: match.range)
        }
    }

    private static func applyFilePathHighlights(
        to attributedString: NSMutableAttributedString,
        style: MarkdownMessageTextStyle,
        pointSize: CGFloat
    ) {
        let pattern = #"(?<![\w:/])((?:~|\.\.?|[A-Za-z0-9_.-]+)?(?:/[A-Za-z0-9_.-]+)+|(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+)(?::[0-9]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let fullRange = NSRange(location: 0, length: attributedString.length)
        regex.enumerateMatches(in: attributedString.string, range: fullRange) { match, _, _ in
            guard let match else { return }
            if attributedString.attribute(.link, at: match.range.location, effectiveRange: nil) != nil {
                return
            }
            attributedString.addAttributes([
                .font: NSFont.monospacedSystemFont(ofSize: pointSize, weight: .regular),
                .foregroundColor: style.linkColor
            ], range: match.range)
        }
    }
}

private final class SelectableTextContainerView: NSView {
    let textView = NSTextView()
    var onHeightChanged: ((CGFloat) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubview(textView)
    }

    override func layout() {
        super.layout()
        textView.frame = bounds
        updateTextContainerSize()
        recalculateHeight()
    }

    func forceLayoutRecalculation() {
        updateTextContainerSize()
        textView.needsLayout = true
        textView.layoutSubtreeIfNeeded()
        recalculateHeight()
    }

    func recalculateHeight() {
        guard let textContainer = textView.textContainer else { return }
        updateTextContainerSize()
        textView.layoutManager?.ensureLayout(for: textContainer)
        let usedRect = textView.layoutManager?.usedRect(for: textContainer) ?? .zero
        onHeightChanged?(max(28, ceil(usedRect.height) + 4))
    }

    private func updateTextContainerSize() {
        let width = max(bounds.width, 1)
        textView.frame = NSRect(origin: .zero, size: NSSize(width: width, height: bounds.height))
        textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    }
}

struct MarkdownBlock: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case heading(level: Int)
        case paragraph
        case bullet
        case code
        case table
    }

    let kind: Kind
    let text: String

    static func parse(_ content: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var codeLines: [String] = []
        var tableLines: [String] = []
        var inCodeBlock = false

        func flushParagraph() {
            let text = paragraphLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(MarkdownBlock(kind: .paragraph, text: text))
            }
            paragraphLines.removeAll()
        }

        func flushCode() {
            blocks.append(MarkdownBlock(kind: .code, text: codeLines.joined(separator: "\n")))
            codeLines.removeAll()
        }

        func flushTable() {
            guard !tableLines.isEmpty else { return }
            if tableLines.count >= 2, tableLines.contains(where: isTableSeparator) {
                let rows = tableLines
                    .filter { !isTableSeparator($0) }
                    .map(tableCells)
                    .filter { !$0.isEmpty }
                let text = formattedTable(rows)
                if !text.isEmpty {
                    blocks.append(MarkdownBlock(kind: .table, text: text))
                }
            } else {
                paragraphLines.append(contentsOf: tableLines)
            }
            tableLines.removeAll()
        }

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if inCodeBlock {
                    flushCode()
                    inCodeBlock = false
                } else {
                    flushTable()
                    flushParagraph()
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeLines.append(rawLine)
                continue
            }

            if line.isEmpty {
                flushTable()
                flushParagraph()
                continue
            }

            if isTableCandidate(line) {
                flushParagraph()
                tableLines.append(line)
                continue
            } else {
                flushTable()
            }

            if let heading = heading(from: line) {
                flushParagraph()
                blocks.append(MarkdownBlock(kind: .heading(level: heading.level), text: heading.text))
                continue
            }

            if let bullet = bulletText(from: line) {
                flushParagraph()
                blocks.append(MarkdownBlock(kind: .bullet, text: bullet))
                continue
            }

            paragraphLines.append(rawLine)
        }

        if inCodeBlock {
            flushCode()
        }
        flushTable()
        flushParagraph()

        return blocks.isEmpty ? [MarkdownBlock(kind: .paragraph, text: content)] : blocks
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        guard line.hasPrefix("#") else { return nil }
        let markerCount = line.prefix { $0 == "#" }.count
        guard (1...6).contains(markerCount) else { return nil }
        let rest = line.dropFirst(markerCount)
        guard rest.first == " " else { return nil }
        let text = rest.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : (markerCount, text)
    }

    private static func bulletText(from line: String) -> String? {
        for marker in ["* ", "- ", "\u{2022} "] {
            if line.hasPrefix(marker) {
                return String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
            }
        }

        let parts = line.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2,
           let number = Int(parts[0]),
           number > 0,
           parts[1].hasPrefix(" ") {
            return String(parts[1]).trimmingCharacters(in: .whitespaces)
        }

        return nil
    }

    private static func isTableCandidate(_ line: String) -> Bool {
        line.contains("|") && tableCells(line).count >= 2
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(line)
        guard !cells.isEmpty else { return false }
        return cells.allSatisfy { cell in
            let cleaned = cell.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
            return cleaned.trimmingCharacters(in: .whitespaces).isEmpty && cell.contains("-")
        }
    }

    private static func tableCells(_ line: String) -> [String] {
        var cells = line.split(separator: "|", omittingEmptySubsequences: false).map {
            String($0).trimmingCharacters(in: .whitespaces)
        }
        if cells.first?.isEmpty == true {
            cells.removeFirst()
        }
        if cells.last?.isEmpty == true {
            cells.removeLast()
        }
        return cells
    }

    private static func formattedTable(_ rows: [[String]]) -> String {
        guard let columnCount = rows.map(\.count).max(), columnCount > 0 else { return "" }
        let widths = (0..<columnCount).map { column in
            rows.map { row in
                column < row.count ? row[column].count : 0
            }.max() ?? 0
        }
        return rows.map { row in
            (0..<columnCount).map { column in
                let value = column < row.count ? row[column] : ""
                return value.padding(toLength: widths[column], withPad: " ", startingAt: 0)
            }.joined(separator: "  ")
        }.joined(separator: "\n")
    }
}
