import Foundation

struct HotkeyBinding: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: Modifiers
    let displayName: String

    static let defaultToggle = HotkeyBinding(
        keyCode: 49,
        modifiers: [.control],
        displayName: "Control + Space"
    )

    static let defaultPushToTalk = HotkeyBinding(
        keyCode: 10,
        modifiers: [],
        displayName: "§"
    )

    static let defaultVoiceGate = HotkeyBinding(
        keyCode: 49,
        modifiers: [.control, .option],
        displayName: "Control + Option + Space"
    )

    static let defaultPrimeToggle = HotkeyBinding(
        keyCode: 18,
        modifiers: [.control],
        displayName: "Control + 1"
    )

    static let defaultVoiceGateVerifierToggle = HotkeyBinding(
        keyCode: 19,
        modifiers: [.control],
        displayName: "Control + 2"
    )

    static let defaultVoiceModeActivation = HotkeyBinding(
        keyCode: 20,
        modifiers: [.control],
        displayName: "Control + 3"
    )

    static let legacyDefaultToggle = HotkeyBinding(
        keyCode: 49,
        modifiers: [.option],
        displayName: "Option + Space"
    )

    static let legacyDefaultPrimeToggle = HotkeyBinding(
        keyCode: 10,
        modifiers: [.control],
        displayName: "Control + §"
    )

    static let legacyDefaultVoiceGateVerifierToggle = HotkeyBinding(
        keyCode: 10,
        modifiers: [.option],
        displayName: "Option + §"
    )

    struct Modifiers: Codable, OptionSet, Equatable, Sendable {
        let rawValue: UInt32

        static let command = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let control = Modifiers(rawValue: 1 << 2)
        static let shift = Modifiers(rawValue: 1 << 3)
    }
}
