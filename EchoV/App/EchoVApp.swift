import AppKit

@main
@MainActor
enum EchoVApp {
    private static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}
