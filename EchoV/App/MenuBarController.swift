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

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "Toggle Recording", action: #selector(toggleRecording), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

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
}
