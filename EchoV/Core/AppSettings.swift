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

    var clipboardInsertionMode: ClipboardInsertionMode {
        didSet {
            userDefaults.set(clipboardInsertionMode.rawValue, forKey: Keys.clipboardInsertionMode)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.toggleHotkey = Self.loadHotkey(forKey: Keys.toggleHotkey, from: userDefaults) ?? .defaultToggle
        self.pushToTalkHotkey = Self.loadHotkey(forKey: Keys.pushToTalkHotkey, from: userDefaults) ?? .defaultPushToTalk
        self.isHistoryEnabled = userDefaults.object(forKey: Keys.isHistoryEnabled) as? Bool ?? true
        self.shouldDeleteTemporaryAudio = userDefaults.object(forKey: Keys.shouldDeleteTemporaryAudio) as? Bool ?? true
        self.clipboardInsertionMode = Self.loadClipboardInsertionMode(from: userDefaults)
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
}

private enum Keys {
    static let toggleHotkey = "settings.toggleHotkey"
    static let pushToTalkHotkey = "settings.pushToTalkHotkey"
    static let isHistoryEnabled = "settings.isHistoryEnabled"
    static let shouldDeleteTemporaryAudio = "settings.shouldDeleteTemporaryAudio"
    static let clipboardInsertionMode = "settings.clipboardInsertionMode"
}
