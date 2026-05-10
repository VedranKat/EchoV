import ApplicationServices

struct AccessibilityPermissionService: Sendable {
    func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @MainActor
    func promptForAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
