import AppKit
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private let container: AppContainer
    private lazy var settingsWindowController = SettingsWindowController(container: container)

    init(container: AppContainer) {
        self.container = container
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.container.appState.onStatusChanged = { [weak self] in
            self?.rebuildMenu()
        }
        configure()
    }

    private func configure() {
        statusItem.button?.title = "EchoV"
        rebuildMenu()
    }

    private func rebuildMenu() {
        statusItem.button?.title = "EchoV"
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
}
