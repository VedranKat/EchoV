import AppKit
import ApplicationServices
import Foundation

@MainActor
struct SelectedTextCaptureService {
    private let clipboard = ClipboardService()
    private let accessibilityPermission: AccessibilityPermissionService
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
