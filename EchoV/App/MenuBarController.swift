import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let container: AppContainer
    private let openTextResponseSession: (UUID) -> Void
    private lazy var settingsWindowController = SettingsWindowController(container: container)

    init(
        container: AppContainer,
        openTextResponseSession: @escaping (UUID) -> Void
    ) {
        self.container = container
        self.openTextResponseSession = openTextResponseSession
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        self.container.appState.onStatusChanged = { [weak self] in
            self?.rebuildMenu()
        }
        self.container.permissionState.onPermissionsChanged = { [weak self] in
            self?.rebuildMenu()
        }
        configure()
    }

    private func configure() {
        configureStatusButton()
        rebuildMenu()
    }

    private func rebuildMenu() {
        configureStatusButton()
        let menu = NSMenu()
        menu.delegate = self
        populate(menu)
        self.statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        container.refreshPermissions(notifyOnChange: false)
        populate(menu)
    }

    private func populate(_ menu: NSMenu) {
        menu.removeAllItems()

        addTextResponseItems(to: menu)

        if !container.permissionState.isAccessibilityTrusted {
            let accessibilityItem = NSMenuItem(
                title: "Request Accessibility Access",
                action: #selector(requestAccessibilityAccess),
                keyEquivalent: ""
            )
            accessibilityItem.target = self
            menu.addItem(accessibilityItem)
            menu.addItem(NSMenuItem.separator())
        }

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let stopItem = NSMenuItem(title: "Stop EchoV", action: #selector(stopEchoV), keyEquivalent: "")
        stopItem.target = self
        menu.addItem(stopItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit EchoV", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }

    private func addTextResponseItems(to menu: NSMenu) {
        let sessions = container.textResponseSessions.sessions
        guard let latestSession = sessions.first else {
            return
        }

        let item = NSMenuItem(
            title: "Open Text Chat",
            action: #selector(openTextResponseSessionFromMenu(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = latestSession.id.uuidString
        menu.addItem(item)
        menu.addItem(NSMenuItem.separator())
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        button.title = ""
        button.image = makeMenuBarImage()
        button.imagePosition = .imageOnly
        button.toolTip = "EchoV - \(container.appState.state.menuTitle)"
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    @objc private func requestAccessibilityAccess() {
        container.promptForAccessibilityAccess()
        rebuildMenu()
    }

    @objc private func stopEchoV() {
        Task {
            await container.stopActiveWork()
        }
    }

    @objc private func openTextResponseSessionFromMenu(_ sender: NSMenuItem) {
        guard
            let rawID = sender.representedObject as? String,
            let sessionID = UUID(uuidString: rawID)
        else {
            return
        }

        openTextResponseSession(sessionID)
    }

    private func makeMenuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        defer {
            image.unlockFocus()
            image.isTemplate = true
        }

        NSColor.black.setFill()

        let bars: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = [
            (2.0, 7.0, 2.0, 4.0),
            (5.0, 4.0, 2.0, 10.0),
            (8.0, 2.0, 2.0, 14.0),
            (11.0, 5.0, 2.0, 8.0),
            (14.0, 7.0, 2.0, 4.0)
        ]

        for bar in bars {
            NSBezierPath(
                roundedRect: NSRect(x: bar.x, y: bar.y, width: bar.width, height: bar.height),
                xRadius: 1,
                yRadius: 1
            )
            .fill()
        }

        NSBezierPath(ovalIn: NSRect(x: 7.0, y: 7.0, width: 4.0, height: 4.0))
            .fill()

        return image
    }
}
