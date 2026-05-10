import AppKit
import ApplicationServices

struct ClipboardService: Sendable {
    @MainActor
    func snapshot() -> PasteboardSnapshot {
        PasteboardSnapshot()
    }

    @MainActor
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @MainActor
    func restore(_ snapshot: PasteboardSnapshot) {
        snapshot.restore()
    }
}

struct PasteInsertionService: TextInsertionService {
    private let clipboard = ClipboardService()
    private let accessibilityPermission: AccessibilityPermissionService
    private let restoreDelay: Duration

    init(
        accessibilityPermission: AccessibilityPermissionService,
        restoreDelay: Duration = .milliseconds(350)
    ) {
        self.accessibilityPermission = accessibilityPermission
        self.restoreDelay = restoreDelay
    }

    @MainActor
    func insert(_ text: String) async throws -> InsertionResult {
        let snapshot = clipboard.snapshot()
        clipboard.copy(text)

        guard accessibilityPermission.isTrusted() else {
            return InsertionResult(insertedDirectly: false, copiedToClipboard: true)
        }

        guard postPasteShortcut() else {
            return InsertionResult(insertedDirectly: false, copiedToClipboard: true)
        }

        try? await Task.sleep(for: restoreDelay)
        clipboard.restore(snapshot)

        return InsertionResult(
            insertedDirectly: true,
            copiedToClipboard: true,
            restoredPreviousClipboard: true
        )
    }

    private func postPasteShortcut() -> Bool {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
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

struct ClipboardFallbackInsertionService: TextInsertionService {
    private let clipboard = ClipboardService()

    @MainActor
    func insert(_ text: String) async throws -> InsertionResult {
        clipboard.copy(text)
        return InsertionResult(insertedDirectly: false, copiedToClipboard: true)
    }
}
