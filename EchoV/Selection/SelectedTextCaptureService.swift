import AppKit
import ApplicationServices
import Foundation

@MainActor
struct SelectedTextCaptureService {
    private let clipboard = ClipboardService()
    private let accessibilityPermission: AccessibilityPermissionService
    private let selectionInspector = AccessibilitySelectedTextInspector()
    private let copyDelay: Duration

    init(
        accessibilityPermission: AccessibilityPermissionService,
        copyDelay: Duration = .milliseconds(120)
    ) {
        self.accessibilityPermission = accessibilityPermission
        self.copyDelay = copyDelay
    }

    func captureSelectedText() async -> String? {
        guard accessibilityPermission.isTrusted() else {
            return nil
        }

        switch selectionInspector.focusedSelectionState() {
        case .selectedText(let text):
            return AccessibilitySelectedTextInspector.normalizedSelectedText(text)
        case .selectionPresent:
            break
        case .noSelection:
            return nil
        case .unknown(let clipboardFallbackAllowed):
            guard clipboardFallbackAllowed else {
                return nil
            }
        }

        return await captureSelectedTextViaClipboard()
    }

    private func captureSelectedTextViaClipboard() async -> String? {
        let snapshot = clipboard.snapshot()
        let marker = "EchoVSelectionProbe-\(UUID().uuidString)"
        clipboard.copy(marker)

        guard postCopyShortcut() else {
            clipboard.restore(snapshot)
            return nil
        }

        try? await Task.sleep(for: copyDelay)
        let copiedText = NSPasteboard.general.string(forType: .string) ?? ""
        clipboard.restore(snapshot)

        let trimmed = copiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != marker else {
            return nil
        }

        return trimmed
    }

    private func postCopyShortcut() -> Bool {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

enum FocusedTextSelectionState: Equatable {
    case selectedText(String)
    case selectionPresent
    case noSelection
    case unknown(clipboardFallbackAllowed: Bool)
}

struct AccessibilitySelectedTextInspector {
    func focusedSelectionState() -> FocusedTextSelectionState {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return .unknown(clipboardFallbackAllowed: true)
        }

        guard let focusedElement = focusedElement(for: application.processIdentifier) else {
            return .unknown(clipboardFallbackAllowed: Self.clipboardFallbackAllowed(for: application.bundleIdentifier))
        }

        let selectedText = selectedText(from: focusedElement)
        let selectedRangeLengths = selectedRangeLengths(from: focusedElement)
        return Self.selectionState(
            selectedText: selectedText.value,
            selectedTextWasReadable: selectedText.wasReadable,
            selectedRangeLengths: selectedRangeLengths.value,
            selectedRangeLengthsWereReadable: selectedRangeLengths.wasReadable,
            clipboardFallbackAllowed: Self.clipboardFallbackAllowed(for: application.bundleIdentifier)
        )
    }

    static func selectionState(
        selectedText: String?,
        selectedTextWasReadable: Bool,
        selectedRangeLengths: [Int]?,
        selectedRangeLengthsWereReadable: Bool,
        clipboardFallbackAllowed: Bool
    ) -> FocusedTextSelectionState {
        if selectedRangeLengthsWereReadable {
            let selectedLength = selectedRangeLengths?.reduce(0, +) ?? 0
            guard selectedLength > 0 else {
                return .noSelection
            }

            if let text = selectedText.flatMap(Self.normalizedSelectedText) {
                return .selectedText(text)
            }

            return .selectionPresent
        }

        if selectedTextWasReadable {
            if let text = selectedText.flatMap(Self.normalizedSelectedText) {
                return .selectedText(text)
            }

            return .noSelection
        }

        return .unknown(clipboardFallbackAllowed: clipboardFallbackAllowed)
    }

    static func clipboardFallbackAllowed(for bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else {
            return true
        }

        return !copiesLineWithoutSelection(bundleIdentifier: bundleIdentifier)
    }

    static func normalizedSelectedText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func focusedElement(for processIdentifier: pid_t) -> AXUIElement? {
        let applicationElement = AXUIElementCreateApplication(processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )
        guard result == .success else {
            return nil
        }

        return value as! AXUIElement?
    }

    private func selectedText(from element: AXUIElement) -> AccessibilityAttributeRead<String> {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            &value
        )
        guard result == .success else {
            return .unreadable
        }

        return .read(value as? String ?? "")
    }

    private func selectedRangeLengths(from element: AXUIElement) -> AccessibilityAttributeRead<[Int]> {
        if let selectedRangeLength = selectedRangeLength(from: element) {
            return .read([selectedRangeLength])
        }

        if let selectedRangesLengths = selectedRangesLengths(from: element) {
            return .read(selectedRangesLengths)
        }

        return .unreadable
    }

    private func selectedRangeLength(from element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        )
        guard result == .success, let value else {
            return nil
        }

        let axValue = value as! AXValue
        return rangeLength(from: axValue)
    }

    private func selectedRangesLengths(from element: AXUIElement) -> [Int]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangesAttribute as CFString,
            &value
        )
        guard result == .success, let axValues = value as? [AXValue] else {
            return nil
        }

        return axValues.compactMap(rangeLength)
    }

    private func rangeLength(from value: AXValue) -> Int? {
        guard AXValueGetType(value) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range) else {
            return nil
        }

        return max(range.length, 0)
    }

    private static func copiesLineWithoutSelection(bundleIdentifier: String) -> Bool {
        let normalizedIdentifier = bundleIdentifier.lowercased()
        return normalizedIdentifier.hasPrefix("com.jetbrains.")
            || normalizedIdentifier == "com.google.android.studio"
            || normalizedIdentifier == "com.apple.dt.xcode"
            || normalizedIdentifier == "com.microsoft.vscode"
            || normalizedIdentifier == "com.microsoft.vscodeinsiders"
            || normalizedIdentifier == "com.cursor.cursor"
            || normalizedIdentifier == "com.todesktop.230313mzl4w4u92"
            || normalizedIdentifier.hasPrefix("com.sublimetext.")
    }
}

private struct AccessibilityAttributeRead<Value> {
    let value: Value?
    let wasReadable: Bool

    static var unreadable: AccessibilityAttributeRead<Value> {
        AccessibilityAttributeRead(value: nil, wasReadable: false)
    }

    static func read(_ value: Value) -> AccessibilityAttributeRead<Value> {
        AccessibilityAttributeRead(value: value, wasReadable: true)
    }
}
