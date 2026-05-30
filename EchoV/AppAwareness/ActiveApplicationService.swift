import AppKit

@MainActor
struct ActiveApplicationService {
    func frontmostApplication() -> TargetAppContext {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return .unknown
        }

        return TargetAppContext(
            localizedName: application.localizedName,
            bundleIdentifier: application.bundleIdentifier
        )
    }
}
