import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let container: AppContainer
    private var window: NSWindow?

    init(container: AppContainer) {
        self.container = container
    }

    func show() {
        if window == nil {
            window = makeWindow()
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let rootView = SettingsRootView()
            .environment(container)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "EchoV Settings"
        window.center()
        window.contentView = NSHostingView(rootView: rootView)
        window.isReleasedWhenClosed = false
        return window
    }
}
