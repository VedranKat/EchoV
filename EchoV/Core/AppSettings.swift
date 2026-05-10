import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private let userDefaults: UserDefaults

    var hotkey = HotkeyBinding.defaultToggle
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

    var asrComputeMode: ASRComputeMode {
        didSet {
            userDefaults.set(asrComputeMode.rawValue, forKey: Keys.asrComputeMode)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.isHistoryEnabled = userDefaults.object(forKey: Keys.isHistoryEnabled) as? Bool ?? true
        self.shouldDeleteTemporaryAudio = userDefaults.object(forKey: Keys.shouldDeleteTemporaryAudio) as? Bool ?? true
        self.asrComputeMode = userDefaults.string(forKey: Keys.asrComputeMode)
            .flatMap(ASRComputeMode.init(rawValue:)) ?? .all
    }
}

private enum Keys {
    static let isHistoryEnabled = "settings.isHistoryEnabled"
    static let shouldDeleteTemporaryAudio = "settings.shouldDeleteTemporaryAudio"
    static let asrComputeMode = "settings.asrComputeMode"
}
