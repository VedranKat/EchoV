import AppKit
import SwiftUI

@MainActor
final class TextResponseWindowController {
    private let container: AppContainer
    private var window: NSWindow?

    init(container: AppContainer) {
        self.container = container
    }

    func show(sessionID: UUID) {
        container.textResponseSessions.select(sessionID)

        if window == nil {
            window = makeWindow()
        }

        if let window, !window.isVisible {
            positionNearNotificationArea(window)
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let rootView = TextResponseSessionView()
            .environment(container)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "EchoV Text Response"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 760, height: 520)
        window.tabbingMode = .disallowed
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: rootView)
        window.isReleasedWhenClosed = false
        positionNearNotificationArea(window)
        return window
    }

    private func positionNearNotificationArea(_ window: NSWindow) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 880, height: 640)
        let margin: CGFloat = 22
        let width = min(max(window.frame.width, window.minSize.width), max(window.minSize.width, visibleFrame.width - (margin * 2)))
        let height = min(max(window.frame.height, window.minSize.height), max(window.minSize.height, visibleFrame.height - (margin * 2)))
        let origin = NSPoint(
            x: visibleFrame.maxX - width - margin,
            y: visibleFrame.midY - (height / 2)
        )

        window.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: false)
    }
}
