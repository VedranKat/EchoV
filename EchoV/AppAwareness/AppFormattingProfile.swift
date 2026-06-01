import Foundation

enum AppFormattingProfile: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case general
    case chat
    case email
    case code
    case terminal
    case document

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            "General"
        case .chat:
            "Chat"
        case .email:
            "Email"
        case .code:
            "Code"
        case .terminal:
            "Terminal"
        case .document:
            "Document"
        }
    }

    var promptInstruction: String {
        switch self {
        case .general:
            "Clean for a general text field. Preserve the speaker's intent, tone, and formatting unless the transcript clearly needs punctuation or spacing."
        case .chat:
            "Clean for chat or messaging. Keep the result concise and conversational. Do not add formal greetings, sign-offs, or extra structure unless dictated."
        case .email:
            "Clean for email. Use complete sentences and readable paragraphs while preserving the speaker's intent. Do not invent greetings, sign-offs, recipients, or commitments."
        case .code:
            "Clean for a code editor or technical workflow. Preserve identifiers, API names, capitalization, punctuation, symbols, commands, and code-like fragments. Avoid smart punctuation."
        case .terminal:
            "Clean for a terminal or shell-oriented field. Output shell text, not prose. Convert clear spoken command punctuation like \"dash dash\" to -- and \"new line\" to line breaks. Preserve commands, flags, paths, casing, and punctuation."
        case .document:
            "Clean for notes or long-form writing. Use readable sentence and paragraph structure while preserving the speaker's order and meaning."
        }
    }

    static func profile(for context: TargetAppContext) -> AppFormattingProfile {
        let bundleID = context.bundleIdentifier?.lowercased() ?? ""
        let appName = context.localizedName?.lowercased() ?? ""

        if emailBundleIDs.contains(bundleID) || appName.contains("mail") || appName.contains("outlook") {
            return .email
        }

        if chatBundleIDs.contains(bundleID) || chatAppNameFragments.contains(where: appName.contains) {
            return .chat
        }

        if terminalBundleIDs.contains(bundleID) || terminalAppNameFragments.contains(where: appName.contains) {
            return .terminal
        }

        if codeBundleIDs.contains(bundleID) || codeAppNameFragments.contains(where: appName.contains) {
            return .code
        }

        if documentBundleIDs.contains(bundleID) || documentAppNameFragments.contains(where: appName.contains) {
            return .document
        }

        return .general
    }

    private static let emailBundleIDs: Set<String> = [
        "com.apple.mail",
        "com.microsoft.outlook"
    ]

    private static let chatBundleIDs: Set<String> = [
        "com.apple.mobilesms",
        "com.hnc.discord",
        "com.tinyspeck.slackmacgap",
        "us.zoom.xos"
    ]

    private static let terminalBundleIDs: Set<String> = [
        "com.apple.terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.warp-stable"
    ]

    private static let codeBundleIDs: Set<String> = [
        "com.apple.dt.xcode",
        "com.microsoft.vscode",
        "com.todesktop.230313mzl4w4u92"
    ]

    private static let documentBundleIDs: Set<String> = [
        "com.apple.notes",
        "com.apple.textedit",
        "com.apple.iwork.pages",
        "com.microsoft.word",
        "md.obsidian"
    ]

    private static let chatAppNameFragments = [
        "discord",
        "messages",
        "slack",
        "zoom"
    ]

    private static let terminalAppNameFragments = [
        "ghostty",
        "iterm",
        "terminal",
        "warp"
    ]

    private static let codeAppNameFragments = [
        "cursor",
        "visual studio code",
        "xcode"
    ]

    private static let documentAppNameFragments = [
        "notes",
        "obsidian",
        "pages",
        "textedit",
        "word"
    ]
}
