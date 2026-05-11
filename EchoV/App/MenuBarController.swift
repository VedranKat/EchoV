import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let container: AppContainer
    private lazy var settingsWindowController = SettingsWindowController(container: container)

    init(container: AppContainer) {
        self.container = container
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.container.appState.onStatusChanged = { [weak self] in
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

        let statusItem = NSMenuItem(title: container.appState.state.menuTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        if let detail = container.appState.lastDetail, !detail.isEmpty {
            let detailItem = NSMenuItem(title: "Status: \(shortMenuText(detail))", action: nil, keyEquivalent: "")
            detailItem.isEnabled = false
            menu.addItem(detailItem)
        }

        if let error = container.appState.lastError {
            let errorItem = NSMenuItem(title: "Error: \(shortMenuText(error.userMessage))", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)

            if let details = error.technicalDetails, !details.isEmpty {
                let detailsItem = NSMenuItem(title: shortMenuText(details), action: nil, keyEquivalent: "")
                detailsItem.isEnabled = false
                menu.addItem(detailsItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "Toggle Recording", action: #selector(toggleRecording), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        if !container.accessibilityPermission.isTrusted() {
            let accessibilityItem = NSMenuItem(
                title: "Request Accessibility Access",
                action: #selector(requestAccessibilityAccess),
                keyEquivalent: ""
            )
            accessibilityItem.target = self
            menu.addItem(accessibilityItem)
        }

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit EchoV", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        self.statusItem.menu = menu
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

    @objc private func toggleRecording() {
        Task {
            await container.pipeline.toggleRecording()
            rebuildMenu()
        }
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    @objc private func requestAccessibilityAccess() {
        container.accessibilityPermission.promptForAccess()
        rebuildMenu()
    }

    private func shortMenuText(_ text: String) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        let limit = 86

        guard singleLine.count > limit else {
            return singleLine
        }

        let endIndex = singleLine.index(singleLine.startIndex, offsetBy: limit)
        return "\(singleLine[..<endIndex])..."
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
