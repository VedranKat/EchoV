import Foundation

struct HotkeyBinding: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: Modifiers
    let displayName: String

    static let defaultToggle = HotkeyBinding(
        keyCode: 49,
        modifiers: [.option],
        displayName: "Option + Space"
    )

    static let defaultPushToTalk = HotkeyBinding(
        keyCode: 10,
        modifiers: [],
        displayName: "§"
    )

    struct Modifiers: Codable, OptionSet, Equatable, Sendable {
        let rawValue: UInt32

        static let command = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let control = Modifiers(rawValue: 1 << 2)
        static let shift = Modifiers(rawValue: 1 << 3)
    }
}
