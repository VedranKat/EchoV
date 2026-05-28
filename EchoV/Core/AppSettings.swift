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

    var voiceModeTextActivationHotkey: HotkeyBinding? {
        didSet {
            saveHotkey(voiceModeTextActivationHotkey, forKey: Keys.voiceModeTextActivationHotkey)
        }
    }

    var stopHotkey: HotkeyBinding? {
        didSet {
            saveHotkey(stopHotkey, forKey: Keys.stopHotkey)
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

    var isVoiceGuardEnabled: Bool {
        didSet {
            userDefaults.set(isVoiceGuardEnabled, forKey: Keys.isVoiceGuardEnabled)
        }
    }

    var isVoiceGuardEnabledForVoiceGate: Bool {
        didSet {
            userDefaults.set(isVoiceGuardEnabledForVoiceGate, forKey: Keys.isVoiceGuardEnabledForVoiceGate)
        }
    }

    var isVoiceGuardEnabledForVoiceModeCommands: Bool {
        didSet {
            userDefaults.set(isVoiceGuardEnabledForVoiceModeCommands, forKey: Keys.isVoiceGuardEnabledForVoiceModeCommands)
        }
    }

    var isVoiceGuardEnabledForVoiceModeRequests: Bool {
        didSet {
            userDefaults.set(isVoiceGuardEnabledForVoiceModeRequests, forKey: Keys.isVoiceGuardEnabledForVoiceModeRequests)
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

    var voiceModePromptEndingMode: VoiceModePromptEndingMode {
        didSet {
            userDefaults.set(voiceModePromptEndingMode.rawValue, forKey: Keys.voiceModePromptEndingMode)
        }
    }

    var voiceModeAdaptiveFastPauseSeconds: TimeInterval {
        didSet {
            userDefaults.set(voiceModeAdaptiveFastPauseSeconds, forKey: Keys.voiceModeAdaptiveFastPauseSeconds)
        }
    }

    var voiceModeAdaptivePausePreset: VoiceModeAdaptivePausePreset {
        didSet {
            userDefaults.set(voiceModeAdaptivePausePreset.rawValue, forKey: Keys.voiceModeAdaptivePausePreset)
        }
    }

    var voiceModeAdaptiveMinimumSpeechSeconds: TimeInterval {
        didSet {
            userDefaults.set(voiceModeAdaptiveMinimumSpeechSeconds, forKey: Keys.voiceModeAdaptiveMinimumSpeechSeconds)
        }
    }

    var voiceModeStopPhrase: String {
        didSet {
            userDefaults.set(Self.normalizedPromptPhrase(voiceModeStopPhrase), forKey: Keys.voiceModeStopPhrase)
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

    var isVoiceModePromptPreviewEnabled: Bool {
        didSet {
            userDefaults.set(isVoiceModePromptPreviewEnabled, forKey: Keys.isVoiceModePromptPreviewEnabled)
        }
    }

    var isVoiceModeHUDEnabled: Bool {
        didSet {
            userDefaults.set(isVoiceModeHUDEnabled, forKey: Keys.isVoiceModeHUDEnabled)
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
        self.voiceModeTextActivationHotkey = Self.loadHotkey(
            forKey: Keys.voiceModeTextActivationHotkey,
            from: userDefaults
        ) ?? .defaultVoiceModeTextActivation
        self.stopHotkey = Self.loadHotkey(
            forKey: Keys.stopHotkey,
            from: userDefaults
        ) ?? .defaultStop
        self.isHistoryEnabled = userDefaults.object(forKey: Keys.isHistoryEnabled) as? Bool ?? true
        self.shouldDeleteTemporaryAudio = userDefaults.object(forKey: Keys.shouldDeleteTemporaryAudio) as? Bool ?? true
        self.selectedMicrophoneDeviceID = userDefaults.string(forKey: Keys.selectedMicrophoneDeviceID)
        self.isPostProcessingEnabled = userDefaults.object(forKey: Keys.isPostProcessingEnabled) as? Bool ?? false
        self.postProcessingLevel = Self.loadPostProcessingLevel(from: userDefaults)
        self.clipboardInsertionMode = Self.loadClipboardInsertionMode(from: userDefaults)
        self.voiceGateSilenceTimeout = Self.loadVoiceGateSilenceTimeout(from: userDefaults)
        self.voiceGateSensitivity = Self.loadVoiceGateSensitivity(from: userDefaults)
        let legacyVoiceGateGuardValue = userDefaults.object(forKey: Keys.isVoiceGateSpeakerMatchEnabled) as? Bool
        self.isVoiceGuardEnabled = userDefaults.object(forKey: Keys.isVoiceGuardEnabled) as? Bool ?? legacyVoiceGateGuardValue ?? false
        self.isVoiceGuardEnabledForVoiceGate = userDefaults.object(forKey: Keys.isVoiceGuardEnabledForVoiceGate) as? Bool ?? true
        self.isVoiceGuardEnabledForVoiceModeCommands = userDefaults.object(forKey: Keys.isVoiceGuardEnabledForVoiceModeCommands) as? Bool ?? true
        self.isVoiceGuardEnabledForVoiceModeRequests = userDefaults.object(forKey: Keys.isVoiceGuardEnabledForVoiceModeRequests) as? Bool ?? true
        self.voiceGateSpeakerMatchStrictness = Self.loadVoiceGateSpeakerMatchStrictness(from: userDefaults)
        self.voiceGateSpeakerVerificationMode = Self.loadVoiceGateSpeakerVerificationMode(from: userDefaults)
        self.isVoiceModeEnabled = userDefaults.object(forKey: Keys.isVoiceModeEnabled) as? Bool ?? false
        self.voiceModeResponsePauseSeconds = Self.loadClampedDouble(
            from: userDefaults,
            key: Keys.voiceModeResponsePauseSeconds,
            defaultValue: 1.2,
            range: 0.5...3.0
        )
        self.voiceModePromptEndingMode = Self.loadVoiceModePromptEndingMode(from: userDefaults)
        self.voiceModeAdaptiveFastPauseSeconds = Self.loadClampedDouble(
            from: userDefaults,
            key: Keys.voiceModeAdaptiveFastPauseSeconds,
            defaultValue: 0.6,
            range: 0.4...1.2
        )
        self.voiceModeAdaptivePausePreset = Self.loadVoiceModeAdaptivePausePreset(from: userDefaults)
        self.voiceModeAdaptiveMinimumSpeechSeconds = Self.loadClampedDouble(
            from: userDefaults,
            key: Keys.voiceModeAdaptiveMinimumSpeechSeconds,
            defaultValue: 1.0,
            range: 0.5...3.0
        )
        self.voiceModeStopPhrase = Self.normalizedPromptPhrase(
            userDefaults.string(forKey: Keys.voiceModeStopPhrase) ?? "go ahead"
        )
        self.voiceModeNoSpeechTimeoutSeconds = Self.loadClampedDouble(
            from: userDefaults,
            key: Keys.voiceModeNoSpeechTimeoutSeconds,
            defaultValue: 8.0,
            range: 3.0...15.0
        )
        self.voiceModeResponseBackend = Self.loadVoiceModeResponseBackend(from: userDefaults)
        self.isVoiceModePromptPreviewEnabled = userDefaults.object(forKey: Keys.isVoiceModePromptPreviewEnabled) as? Bool ?? true
        self.isVoiceModeHUDEnabled = userDefaults.object(forKey: Keys.isVoiceModeHUDEnabled) as? Bool ?? true
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
        voiceModeTextActivationHotkey = .defaultVoiceModeTextActivation
        stopHotkey = .defaultStop
    }

    func resetDictationHotkeysToDefaults() {
        toggleHotkey = .defaultToggle
        pushToTalkHotkey = .defaultPushToTalk
        stopHotkey = .defaultStop
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

    private static func loadVoiceModePromptEndingMode(from userDefaults: UserDefaults) -> VoiceModePromptEndingMode {
        guard
            let rawValue = userDefaults.string(forKey: Keys.voiceModePromptEndingMode),
            let mode = VoiceModePromptEndingMode(rawValue: rawValue)
        else {
            return .fixedPause
        }

        return mode
    }

    private static func loadVoiceModeAdaptivePausePreset(from userDefaults: UserDefaults) -> VoiceModeAdaptivePausePreset {
        guard
            let rawValue = userDefaults.string(forKey: Keys.voiceModeAdaptivePausePreset),
            let preset = VoiceModeAdaptivePausePreset(rawValue: rawValue)
        else {
            return .balanced
        }

        return preset
    }

    private static func normalizedPromptPhrase(_ phrase: String) -> String {
        phrase
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
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
    static let voiceModeTextActivationHotkey = "settings.voiceModeTextActivationHotkey"
    static let stopHotkey = "settings.stopHotkey"
    static let isHistoryEnabled = "settings.isHistoryEnabled"
    static let shouldDeleteTemporaryAudio = "settings.shouldDeleteTemporaryAudio"
    static let selectedMicrophoneDeviceID = "settings.selectedMicrophoneDeviceID"
    static let isPostProcessingEnabled = "settings.isPostProcessingEnabled"
    static let postProcessingLevel = "settings.postProcessingLevel"
    static let clipboardInsertionMode = "settings.clipboardInsertionMode"
    static let voiceGateSilenceTimeout = "settings.voiceGateSilenceTimeout"
    static let voiceGateSensitivity = "settings.voiceGateSensitivity"
    static let isVoiceGateSpeakerMatchEnabled = "settings.isVoiceGateSpeakerMatchEnabled"
    static let isVoiceGuardEnabled = "settings.isVoiceGuardEnabled"
    static let isVoiceGuardEnabledForVoiceGate = "settings.isVoiceGuardEnabledForVoiceGate"
    static let isVoiceGuardEnabledForVoiceModeCommands = "settings.isVoiceGuardEnabledForVoiceModeCommands"
    static let isVoiceGuardEnabledForVoiceModeRequests = "settings.isVoiceGuardEnabledForVoiceModeRequests"
    static let voiceGateSpeakerMatchStrictness = "settings.voiceGateSpeakerMatchStrictness"
    static let voiceGateSpeakerVerificationMode = "settings.voiceGateSpeakerVerificationMode"
    static let isVoiceModeEnabled = "settings.isVoiceModeEnabled"
    static let voiceModeResponsePauseSeconds = "settings.voiceModeResponsePauseSeconds"
    static let voiceModePromptEndingMode = "settings.voiceModePromptEndingMode"
    static let voiceModeAdaptiveFastPauseSeconds = "settings.voiceModeAdaptiveFastPauseSeconds"
    static let voiceModeAdaptivePausePreset = "settings.voiceModeAdaptivePausePreset"
    static let voiceModeAdaptiveMinimumSpeechSeconds = "settings.voiceModeAdaptiveMinimumSpeechSeconds"
    static let voiceModeStopPhrase = "settings.voiceModeStopPhrase"
    static let voiceModeNoSpeechTimeoutSeconds = "settings.voiceModeNoSpeechTimeoutSeconds"
    static let voiceModeResponseBackend = "settings.voiceModeResponseBackend"
    static let isVoiceModePromptPreviewEnabled = "settings.isVoiceModePromptPreviewEnabled"
    static let isVoiceModeHUDEnabled = "settings.isVoiceModeHUDEnabled"
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
