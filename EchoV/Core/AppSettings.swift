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

    var voiceGateHotkey: HotkeyBinding? {
        didSet {
            saveHotkey(voiceGateHotkey, forKey: Keys.voiceGateHotkey)
        }
    }

    var primeToggleHotkey: HotkeyBinding? {
        didSet {
            saveHotkey(primeToggleHotkey, forKey: Keys.primeToggleHotkey)
        }
    }

    var voiceGateVerifierToggleHotkey: HotkeyBinding? {
        didSet {
            saveHotkey(voiceGateVerifierToggleHotkey, forKey: Keys.voiceGateVerifierToggleHotkey)
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

    var postProcessingLevel: PostProcessingLevel {
        didSet {
            userDefaults.set(postProcessingLevel.rawValue, forKey: Keys.postProcessingLevel)
        }
    }

    var clipboardInsertionMode: ClipboardInsertionMode {
        didSet {
            userDefaults.set(clipboardInsertionMode.rawValue, forKey: Keys.clipboardInsertionMode)
        }
    }

    var voiceGateSilenceTimeout: VoiceGateSilenceTimeout {
        didSet {
            userDefaults.set(voiceGateSilenceTimeout.rawValue, forKey: Keys.voiceGateSilenceTimeout)
        }
    }

    var voiceGateSensitivity: VoiceGateSensitivity {
        didSet {
            userDefaults.set(voiceGateSensitivity.rawValue, forKey: Keys.voiceGateSensitivity)
        }
    }

    var isVoiceGateSpeakerMatchEnabled: Bool {
        didSet {
            userDefaults.set(isVoiceGateSpeakerMatchEnabled, forKey: Keys.isVoiceGateSpeakerMatchEnabled)
        }
    }

    var voiceGateSpeakerMatchStrictness: VoiceGateSpeakerMatchStrictness {
        didSet {
            userDefaults.set(voiceGateSpeakerMatchStrictness.rawValue, forKey: Keys.voiceGateSpeakerMatchStrictness)
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
        self.toggleHotkey = Self.loadHotkey(
            forKey: Keys.toggleHotkey,
            from: userDefaults,
            migratingDefaultFrom: .legacyDefaultToggle,
            to: .defaultToggle
        ) ?? .defaultToggle
        self.pushToTalkHotkey = Self.loadHotkey(forKey: Keys.pushToTalkHotkey, from: userDefaults) ?? .defaultPushToTalk
        self.voiceGateHotkey = Self.loadHotkey(forKey: Keys.voiceGateHotkey, from: userDefaults) ?? .defaultVoiceGate
        self.primeToggleHotkey = Self.loadHotkey(
            forKey: Keys.primeToggleHotkey,
            from: userDefaults,
            migratingDefaultFrom: .legacyDefaultPrimeToggle,
            to: .defaultPrimeToggle
        ) ?? .defaultPrimeToggle
        self.voiceGateVerifierToggleHotkey = Self.loadHotkey(
            forKey: Keys.voiceGateVerifierToggleHotkey,
            from: userDefaults,
            migratingDefaultFrom: .legacyDefaultVoiceGateVerifierToggle,
            to: .defaultVoiceGateVerifierToggle
        ) ?? .defaultVoiceGateVerifierToggle
        self.isHistoryEnabled = userDefaults.object(forKey: Keys.isHistoryEnabled) as? Bool ?? true
        self.shouldDeleteTemporaryAudio = userDefaults.object(forKey: Keys.shouldDeleteTemporaryAudio) as? Bool ?? true
        self.selectedMicrophoneDeviceID = userDefaults.string(forKey: Keys.selectedMicrophoneDeviceID)
        self.isPostProcessingEnabled = userDefaults.object(forKey: Keys.isPostProcessingEnabled) as? Bool ?? false
        self.postProcessingLevel = Self.loadPostProcessingLevel(from: userDefaults)
        self.clipboardInsertionMode = Self.loadClipboardInsertionMode(from: userDefaults)
        self.voiceGateSilenceTimeout = Self.loadVoiceGateSilenceTimeout(from: userDefaults)
        self.voiceGateSensitivity = Self.loadVoiceGateSensitivity(from: userDefaults)
        self.isVoiceGateSpeakerMatchEnabled = userDefaults.object(forKey: Keys.isVoiceGateSpeakerMatchEnabled) as? Bool ?? false
        self.voiceGateSpeakerMatchStrictness = Self.loadVoiceGateSpeakerMatchStrictness(from: userDefaults)
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
        voiceGateHotkey = .defaultVoiceGate
        primeToggleHotkey = .defaultPrimeToggle
        voiceGateVerifierToggleHotkey = .defaultVoiceGateVerifierToggle
    }

    func resetDictationHotkeysToDefaults() {
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

    private static func loadHotkey(
        forKey key: String,
        from userDefaults: UserDefaults,
        migratingDefaultFrom oldDefault: HotkeyBinding? = nil,
        to newDefault: HotkeyBinding? = nil
    ) -> HotkeyBinding? {
        if userDefaults.bool(forKey: "\(key).cleared") {
            return nil
        }

        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        guard let hotkey = try? JSONDecoder().decode(HotkeyBinding.self, from: data) else {
            return nil
        }

        if let oldDefault, let newDefault, hotkey == oldDefault {
            return newDefault
        }

        return hotkey
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

    private static func loadPostProcessingLevel(from userDefaults: UserDefaults) -> PostProcessingLevel {
        guard
            let rawValue = userDefaults.string(forKey: Keys.postProcessingLevel),
            let level = PostProcessingLevel(rawValue: rawValue)
        else {
            return .balanced
        }

        return level
    }

    private static func loadVoiceGateSilenceTimeout(from userDefaults: UserDefaults) -> VoiceGateSilenceTimeout {
        guard
            let rawValue = userDefaults.string(forKey: Keys.voiceGateSilenceTimeout),
            let timeout = VoiceGateSilenceTimeout(rawValue: rawValue)
        else {
            return .balanced
        }

        return timeout
    }

    private static func loadVoiceGateSensitivity(from userDefaults: UserDefaults) -> VoiceGateSensitivity {
        guard
            let rawValue = userDefaults.string(forKey: Keys.voiceGateSensitivity),
            let sensitivity = VoiceGateSensitivity(rawValue: rawValue)
        else {
            return .medium
        }

        return sensitivity
    }

    private static func loadVoiceGateSpeakerMatchStrictness(from userDefaults: UserDefaults) -> VoiceGateSpeakerMatchStrictness {
        guard
            let rawValue = userDefaults.string(forKey: Keys.voiceGateSpeakerMatchStrictness),
            let strictness = VoiceGateSpeakerMatchStrictness(rawValue: rawValue)
        else {
            return .balanced
        }

        return strictness
    }

    private func applyProxyEnvironment() {
        ProxyEnvironment.apply(proxySettings)
    }
}

private enum Keys {
    static let toggleHotkey = "settings.toggleHotkey"
    static let pushToTalkHotkey = "settings.pushToTalkHotkey"
    static let voiceGateHotkey = "settings.voiceGateHotkey"
    static let primeToggleHotkey = "settings.primeToggleHotkey"
    static let voiceGateVerifierToggleHotkey = "settings.voiceGateVerifierToggleHotkey"
    static let isHistoryEnabled = "settings.isHistoryEnabled"
    static let shouldDeleteTemporaryAudio = "settings.shouldDeleteTemporaryAudio"
    static let selectedMicrophoneDeviceID = "settings.selectedMicrophoneDeviceID"
    static let isPostProcessingEnabled = "settings.isPostProcessingEnabled"
    static let postProcessingLevel = "settings.postProcessingLevel"
    static let clipboardInsertionMode = "settings.clipboardInsertionMode"
    static let voiceGateSilenceTimeout = "settings.voiceGateSilenceTimeout"
    static let voiceGateSensitivity = "settings.voiceGateSensitivity"
    static let isVoiceGateSpeakerMatchEnabled = "settings.isVoiceGateSpeakerMatchEnabled"
    static let voiceGateSpeakerMatchStrictness = "settings.voiceGateSpeakerMatchStrictness"
    static let isProxyEnabled = "settings.isProxyEnabled"
    static let httpProxyHost = "settings.httpProxyHost"
    static let httpProxyPort = "settings.httpProxyPort"
    static let httpsProxyHost = "settings.httpsProxyHost"
    static let httpsProxyPort = "settings.httpsProxyPort"
    static let usesSameProxyForHTTPS = "settings.usesSameProxyForHTTPS"
}
