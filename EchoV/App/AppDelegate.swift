import AppKit
import Observation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer.bootstrap()

    private var menuBarController: MenuBarController?
    private var textResponseWindowController: TextResponseWindowController?
    private var voiceModePromptPreviewWindowController: VoiceModePromptPreviewWindowController?
    private var voiceModeHUDWindowController: VoiceModeHUDWindowController?
    private var liveSubtitleWindowController: LiveSubtitleWindowController?
    private var textResponseNotificationService: TextResponseNotificationService?
    private var isTerminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        let textResponseWindowController = TextResponseWindowController(container: container)
        self.textResponseWindowController = textResponseWindowController
        textResponseNotificationService = TextResponseNotificationService { sessionID in
            textResponseWindowController.show(sessionID: sessionID)
        }
        container.setTextResponseSessionCreatedHandler { [weak self] sessionID, title, responseText in
            self?.textResponseNotificationService?.post(
                sessionID: sessionID,
                title: title,
                responseText: responseText
            )
        }
        menuBarController = MenuBarController(
            container: container,
            openTextResponseSession: { [weak textResponseWindowController] sessionID in
                textResponseWindowController?.show(sessionID: sessionID)
            }
        )
        voiceModePromptPreviewWindowController = VoiceModePromptPreviewWindowController(container: container)
        voiceModeHUDWindowController = VoiceModeHUDWindowController(container: container)
        liveSubtitleWindowController = LiveSubtitleWindowController(container: container)
        container.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if !isTerminating {
            Task {
                await container.stop()
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else {
            return .terminateNow
        }

        isTerminating = true
        Task {
            await container.stop()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        container.refreshPermissions()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "EchoV")
        appMenu.addItem(
            withTitle: "Quit EchoV",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}
