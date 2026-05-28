import AppKit
import Observation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer.bootstrap()

    private var menuBarController: MenuBarController?
    private var textResponseWindowController: TextResponseWindowController?
    private var voiceModePromptPreviewWindowController: VoiceModePromptPreviewWindowController?
    private var voiceModeHUDWindowController: VoiceModeHUDWindowController?
    private var textResponseNotificationService: TextResponseNotificationService?
    private var isTerminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
        menuBarController = MenuBarController(container: container)
        voiceModePromptPreviewWindowController = VoiceModePromptPreviewWindowController(container: container)
        voiceModeHUDWindowController = VoiceModeHUDWindowController(container: container)
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
}
