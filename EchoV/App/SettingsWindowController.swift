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
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "EchoV Settings"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 720, height: 500)
        window.center()
        window.contentView = NSHostingView(rootView: rootView)
        window.isReleasedWhenClosed = false
        return window
    }
}
