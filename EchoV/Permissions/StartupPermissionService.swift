import Foundation
import ServiceManagement

enum StartupRegistrationStatus: Equatable, Sendable {
    enum Method: Equatable, Sendable {
        case serviceManagement
        case launchAgent
    }

    case enabled(Method)
    case notRegistered
    case requiresApproval
    case unavailable
}

struct StartupPermissionService: Sendable {
    private var launchAgentURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appending(path: "Library/LaunchAgents/com.local.echov.login.plist")
    }

    func status() -> StartupRegistrationStatus {
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            return .enabled(.launchAgent)
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled(.serviceManagement)
        case .notRegistered:
            return .notRegistered
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notRegistered
        @unknown default:
            return .unavailable
        }
    }

    @MainActor
    func setStartsAtLogin(_ isEnabled: Bool) throws {
        if isEnabled {
            try register()
        } else {
            try unregister()
        }
    }

    private func register() throws {
        guard SMAppService.mainApp.status == .notFound else {
            do {
                try SMAppService.mainApp.register()
            } catch {
                try installLaunchAgent()
            }
            return
        }

        try installLaunchAgent()
    }

    private func unregister() throws {
        if FileManager.default.fileExists(atPath: launchAgentURL.path) {
            try FileManager.default.removeItem(at: launchAgentURL)
            return
        }

        try SMAppService.mainApp.unregister()
    }

    private func installLaunchAgent() throws {
        let bundleURL = Bundle.main.bundleURL

        guard bundleURL.pathExtension == "app" else {
            throw StartupRegistrationError.appBundleNotFound
        }

        try FileManager.default.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": "com.local.echov.login",
            "ProgramArguments": [
                "/usr/bin/open",
                bundleURL.path
            ],
            "RunAtLoad": true
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)
    }
}

private enum StartupRegistrationError: LocalizedError {
    case appBundleNotFound

    var errorDescription: String? {
        switch self {
        case .appBundleNotFound:
            "EchoV must be launched from an app bundle to enable start at login."
        }
    }
}
