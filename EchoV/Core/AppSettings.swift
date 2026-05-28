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

    var voiceModeActivationHotkey: HotkeyBinding? {
        didSet {
            saveHotkey(voiceModeActivationHotkey, forKey: Keys.voiceModeActivationHotkey)
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

    var voiceGateSpeakerVerificationMode: VoiceGateSpeakerVerificationMode {
        didSet {
            userDefaults.set(voiceGateSpeakerVerificationMode.rawValue, forKey: Keys.voiceGateSpeakerVerificationMode)
        }
    }

    var isVoiceModeEnabled: Bool {
        didSet {
            userDefaults.set(isVoiceModeEnabled, forKey: Keys.isVoiceModeEnabled)
        }
    }

    var voiceModeResponsePauseSeconds: TimeInterval {
        didSet {
            userDefaults.set(voiceModeResponsePauseSeconds, forKey: Keys.voiceModeResponsePauseSeconds)
        }
    }

    var voiceModeNoSpeechTimeoutSeconds: TimeInterval {
        didSet {
            userDefaults.set(voiceModeNoSpeechTimeoutSeconds, forKey: Keys.voiceModeNoSpeechTimeoutSeconds)
        }
    }

    var voiceModeResponseBackend: VoiceModeResponseBackend {
        didSet {
            userDefaults.set(voiceModeResponseBackend.rawValue, forKey: Keys.voiceModeResponseBackend)
        }
    }

    var voiceModeResponseDelivery: VoiceModeResponseDelivery {
        didSet {
            userDefaults.set(voiceModeResponseDelivery.rawValue, forKey: Keys.voiceModeResponseDelivery)
        }
    }

    var textResponseStreamsReplies: Bool {
        didSet {
            userDefaults.set(textResponseStreamsReplies, forKey: Keys.textResponseStreamsReplies)
        }
    }

    var textResponseShowsReasoning: Bool {
        didSet {
            userDefaults.set(textResponseShowsReasoning, forKey: Keys.textResponseShowsReasoning)
        }
    }

    var voiceModeCloudBaseURL: String {
        didSet {
            userDefaults.set(voiceModeCloudBaseURL, forKey: Keys.voiceModeCloudBaseURL)
        }
    }

    var voiceModeCloudModel: String {
        didSet {
            userDefaults.set(voiceModeCloudModel, forKey: Keys.voiceModeCloudModel)
        }
    }

    var voiceModeCloudAPIKey: String {
        didSet {
            VoiceModeCloudAPIKeyStore.save(voiceModeCloudAPIKey)
        }
    }

    var voiceModeKokoroVoiceIdentifier: String {
        didSet {
            userDefaults.set(voiceModeKokoroVoiceIdentifier, forKey: Keys.voiceModeKokoroVoiceIdentifier)
        }
    }

    var voiceModeKokoroSpeed: Double {
        didSet {
            userDefaults.set(voiceModeKokoroSpeed, forKey: Keys.voiceModeKokoroSpeed)
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
        self.voiceModeActivationHotkey = Self.loadHotkey(
            forKey: Keys.voiceModeActivationHotkey,
            from: userDefaults
        ) ?? .defaultVoiceModeActivation
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
        self.voiceGateSpeakerVerificationMode = Self.loadVoiceGateSpeakerVerificationMode(from: userDefaults)
        self.isVoiceModeEnabled = userDefaults.object(forKey: Keys.isVoiceModeEnabled) as? Bool ?? false
        self.voiceModeResponsePauseSeconds = Self.loadClampedDouble(
            from: userDefaults,
            key: Keys.voiceModeResponsePauseSeconds,
            defaultValue: 1.2,
            range: 0.5...3.0
        )
        self.voiceModeNoSpeechTimeoutSeconds = Self.loadClampedDouble(
            from: userDefaults,
            key: Keys.voiceModeNoSpeechTimeoutSeconds,
            defaultValue: 8.0,
            range: 3.0...15.0
        )
        self.voiceModeResponseBackend = Self.loadVoiceModeResponseBackend(from: userDefaults)
        self.voiceModeResponseDelivery = Self.loadVoiceModeResponseDelivery(from: userDefaults)
        self.textResponseStreamsReplies = userDefaults.object(forKey: Keys.textResponseStreamsReplies) as? Bool ?? true
        self.textResponseShowsReasoning = userDefaults.object(forKey: Keys.textResponseShowsReasoning) as? Bool ?? false
        self.voiceModeCloudBaseURL = userDefaults.string(forKey: Keys.voiceModeCloudBaseURL) ?? ""
        self.voiceModeCloudModel = userDefaults.string(forKey: Keys.voiceModeCloudModel) ?? ""
        self.voiceModeCloudAPIKey = VoiceModeCloudAPIKeyStore.load()
        self.voiceModeKokoroVoiceIdentifier = userDefaults.string(forKey: Keys.voiceModeKokoroVoiceIdentifier)
            ?? KokoroVoiceCatalog.defaultVoiceID
        self.voiceModeKokoroSpeed = Self.loadClampedDouble(
            from: userDefaults,
            key: Keys.voiceModeKokoroSpeed,
            defaultValue: 1.0,
            range: 0.5...2.0
        )
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
        voiceModeActivationHotkey = .defaultVoiceModeActivation
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

    private static func loadVoiceGateSpeakerVerificationMode(from userDefaults: UserDefaults) -> VoiceGateSpeakerVerificationMode {
        guard
            let rawValue = userDefaults.string(forKey: Keys.voiceGateSpeakerVerificationMode),
            let mode = VoiceGateSpeakerVerificationMode(rawValue: rawValue)
        else {
            return .startOnly
        }

        return mode
    }

    private static func loadVoiceModeResponseBackend(from userDefaults: UserDefaults) -> VoiceModeResponseBackend {
        guard
            let rawValue = userDefaults.string(forKey: Keys.voiceModeResponseBackend),
            let backend = VoiceModeResponseBackend(rawValue: rawValue)
        else {
            return .localLlama
        }

        return backend
    }

    private static func loadVoiceModeResponseDelivery(from userDefaults: UserDefaults) -> VoiceModeResponseDelivery {
        guard
            let rawValue = userDefaults.string(forKey: Keys.voiceModeResponseDelivery),
            let delivery = VoiceModeResponseDelivery(rawValue: rawValue)
        else {
            return .spoken
        }

        return delivery
    }

    private static func loadClampedDouble(
        from userDefaults: UserDefaults,
        key: String,
        defaultValue: Double,
        range: ClosedRange<Double>
    ) -> Double {
        guard userDefaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return min(max(userDefaults.double(forKey: key), range.lowerBound), range.upperBound)
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
    static let voiceModeActivationHotkey = "settings.voiceModeActivationHotkey"
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
    static let voiceGateSpeakerVerificationMode = "settings.voiceGateSpeakerVerificationMode"
    static let isVoiceModeEnabled = "settings.isVoiceModeEnabled"
    static let voiceModeResponsePauseSeconds = "settings.voiceModeResponsePauseSeconds"
    static let voiceModeNoSpeechTimeoutSeconds = "settings.voiceModeNoSpeechTimeoutSeconds"
    static let voiceModeResponseBackend = "settings.voiceModeResponseBackend"
    static let voiceModeResponseDelivery = "settings.voiceModeResponseDelivery"
    static let textResponseStreamsReplies = "settings.textResponseStreamsReplies"
    static let textResponseShowsReasoning = "settings.textResponseShowsReasoning"
    static let voiceModeCloudBaseURL = "settings.voiceModeCloudBaseURL"
    static let voiceModeCloudModel = "settings.voiceModeCloudModel"
    static let voiceModeKokoroVoiceIdentifier = "settings.voiceModeKokoroVoiceIdentifier"
    static let voiceModeKokoroSpeed = "settings.voiceModeKokoroSpeed"
    static let isProxyEnabled = "settings.isProxyEnabled"
    static let httpProxyHost = "settings.httpProxyHost"
    static let httpProxyPort = "settings.httpProxyPort"
    static let httpsProxyHost = "settings.httpsProxyHost"
    static let httpsProxyPort = "settings.httpsProxyPort"
    static let usesSameProxyForHTTPS = "settings.usesSameProxyForHTTPS"
}
