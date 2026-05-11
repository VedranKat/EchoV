import AppKit
import Observation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let container = AppContainer.bootstrap()

    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController(container: container)
        container.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        container.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        container.refreshPermissions()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
