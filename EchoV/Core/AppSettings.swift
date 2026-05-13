import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private let userDefaults: UserDefaults

    var toggleHotkey: HotkeyBinding? {
        didSet {
            saveHotkey(toggleHotkey, forKey: Keys.toggleHotkey)
        }
    }

    var pushToTalkHotkey: HotkeyBinding? {
        didSet {
            saveHotkey(pushToTalkHotkey, forKey: Keys.pushToTalkHotkey)
        }
    }

    var isHistoryEnabled: Bool {
        didSet {
            userDefaults.set(isHistoryEnabled, forKey: Keys.isHistoryEnabled)
        }
    }

    var shouldDeleteTemporaryAudio: Bool {
        didSet {
            userDefaults.set(shouldDeleteTemporaryAudio, forKey: Keys.shouldDeleteTemporaryAudio)
        }
    }

    var selectedMicrophoneDeviceID: String? {
        didSet {
            if let selectedMicrophoneDeviceID {
                userDefaults.set(selectedMicrophoneDeviceID, forKey: Keys.selectedMicrophoneDeviceID)
            } else {
                userDefaults.removeObject(forKey: Keys.selectedMicrophoneDeviceID)
            }
        }
    }

    var isPostProcessingEnabled: Bool {
        didSet {
            userDefaults.set(isPostProcessingEnabled, forKey: Keys.isPostProcessingEnabled)
        }
    }

    var clipboardInsertionMode: ClipboardInsertionMode {
        didSet {
            userDefaults.set(clipboardInsertionMode.rawValue, forKey: Keys.clipboardInsertionMode)
        }
    }

    var isProxyEnabled: Bool {
        didSet {
            userDefaults.set(isProxyEnabled, forKey: Keys.isProxyEnabled)
            applyProxyEnvironment()
        }
    }

    var httpProxyHost: String {
        didSet {
            userDefaults.set(httpProxyHost, forKey: Keys.httpProxyHost)
            applyProxyEnvironment()
        }
    }

    var httpProxyPort: String {
        didSet {
            userDefaults.set(httpProxyPort, forKey: Keys.httpProxyPort)
            applyProxyEnvironment()
        }
    }

    var httpsProxyHost: String {
        didSet {
            userDefaults.set(httpsProxyHost, forKey: Keys.httpsProxyHost)
            applyProxyEnvironment()
        }
    }

    var httpsProxyPort: String {
        didSet {
            userDefaults.set(httpsProxyPort, forKey: Keys.httpsProxyPort)
            applyProxyEnvironment()
        }
    }

    var usesSameProxyForHTTPS: Bool {
        didSet {
            userDefaults.set(usesSameProxyForHTTPS, forKey: Keys.usesSameProxyForHTTPS)
            applyProxyEnvironment()
        }
    }

    var proxySettings: ProxySettings {
        ProxySettings(
            isEnabled: isProxyEnabled,
            httpHost: httpProxyHost,
            httpPort: httpProxyPort,
            httpsHost: httpsProxyHost,
            httpsPort: httpsProxyPort,
            usesSameProxyForHTTPS: usesSameProxyForHTTPS
        )
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.toggleHotkey = Self.loadHotkey(forKey: Keys.toggleHotkey, from: userDefaults) ?? .defaultToggle
        self.pushToTalkHotkey = Self.loadHotkey(forKey: Keys.pushToTalkHotkey, from: userDefaults) ?? .defaultPushToTalk
        self.isHistoryEnabled = userDefaults.object(forKey: Keys.isHistoryEnabled) as? Bool ?? true
        self.shouldDeleteTemporaryAudio = userDefaults.object(forKey: Keys.shouldDeleteTemporaryAudio) as? Bool ?? true
        self.selectedMicrophoneDeviceID = userDefaults.string(forKey: Keys.selectedMicrophoneDeviceID)
        self.isPostProcessingEnabled = userDefaults.object(forKey: Keys.isPostProcessingEnabled) as? Bool ?? false
        self.clipboardInsertionMode = Self.loadClipboardInsertionMode(from: userDefaults)
        self.isProxyEnabled = userDefaults.object(forKey: Keys.isProxyEnabled) as? Bool ?? false
        self.httpProxyHost = userDefaults.string(forKey: Keys.httpProxyHost) ?? ""
        self.httpProxyPort = userDefaults.string(forKey: Keys.httpProxyPort) ?? ""
        self.httpsProxyHost = userDefaults.string(forKey: Keys.httpsProxyHost) ?? ""
        self.httpsProxyPort = userDefaults.string(forKey: Keys.httpsProxyPort) ?? ""
        self.usesSameProxyForHTTPS = userDefaults.object(forKey: Keys.usesSameProxyForHTTPS) as? Bool ?? true
        applyProxyEnvironment()
    }

    func resetHotkeysToDefaults() {
        toggleHotkey = .defaultToggle
        pushToTalkHotkey = .defaultPushToTalk
    }

    private func saveHotkey(_ hotkey: HotkeyBinding?, forKey key: String) {
        guard let hotkey else {
            userDefaults.removeObject(forKey: key)
            userDefaults.set(true, forKey: "\(key).cleared")
            return
        }

        if let data = try? JSONEncoder().encode(hotkey) {
            userDefaults.set(data, forKey: key)
            userDefaults.removeObject(forKey: "\(key).cleared")
        }
    }

    private static func loadHotkey(forKey key: String, from userDefaults: UserDefaults) -> HotkeyBinding? {
        if userDefaults.bool(forKey: "\(key).cleared") {
            return nil
        }

        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        return try? JSONDecoder().decode(HotkeyBinding.self, from: data)
    }

    private static func loadClipboardInsertionMode(from userDefaults: UserDefaults) -> ClipboardInsertionMode {
        guard
            let rawValue = userDefaults.string(forKey: Keys.clipboardInsertionMode),
            let mode = ClipboardInsertionMode(rawValue: rawValue)
        else {
            return .pasteAndRestorePrevious
        }

        return mode
    }

    private func applyProxyEnvironment() {
        ProxyEnvironment.apply(proxySettings)
    }
}

private enum Keys {
    static let toggleHotkey = "settings.toggleHotkey"
    static let pushToTalkHotkey = "settings.pushToTalkHotkey"
    static let isHistoryEnabled = "settings.isHistoryEnabled"
    static let shouldDeleteTemporaryAudio = "settings.shouldDeleteTemporaryAudio"
    static let selectedMicrophoneDeviceID = "settings.selectedMicrophoneDeviceID"
    static let isPostProcessingEnabled = "settings.isPostProcessingEnabled"
    static let clipboardInsertionMode = "settings.clipboardInsertionMode"
    static let isProxyEnabled = "settings.isProxyEnabled"
    static let httpProxyHost = "settings.httpProxyHost"
    static let httpProxyPort = "settings.httpProxyPort"
    static let httpsProxyHost = "settings.httpsProxyHost"
    static let httpsProxyPort = "settings.httpsProxyPort"
    static let usesSameProxyForHTTPS = "settings.usesSameProxyForHTTPS"
}
