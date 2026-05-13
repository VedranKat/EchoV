import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var hotkeyBeingRecorded: EditableHotkey?
    @State private var microphones: [MicrophoneDevice] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Dictation",
                    subtitle: "Control how EchoV records, stores, and inserts transcripts."
                )

                SettingsCard("Recording", subtitle: "Choose how EchoV starts and captures dictation audio.") {
                    VStack(spacing: 12) {
                        hotkeyRow(
                            editableHotkey: .toggle,
                            icon: "keyboard.badge.ellipsis",
                            title: "Toggle hotkey",
                            subtitle: "Press once to start recording, then again to stop."
                        )

                        DividerLine()

                        hotkeyRow(
                            editableHotkey: .pushToTalk,
                            icon: "mic.badge.plus",
                            title: "Push to talk",
                            subtitle: "Hold the shortcut to record, then release to transcribe."
                        )

                        DividerLine()

                        SettingsRow(
                            icon: "arrow.counterclockwise",
                            title: "Default hotkeys",
                            subtitle: "Restore Option + Space and §."
                        ) {
                            Button("Restore") {
                                container.resetHotkeysToDefaults()
                            }
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "mic",
                            title: "Microphone",
                            subtitle: microphoneSelectionSubtitle
                        ) {
                            HStack(spacing: 8) {
                                Picker(
                                    "Microphone",
                                    selection: Binding<String?>(
                                        get: { container.settings.selectedMicrophoneDeviceID },
                                        set: { container.setSelectedMicrophoneDeviceID($0) }
                                    )
                                ) {
                                    Text("System Default").tag(Optional<String>.none)
                                    ForEach(microphones) { microphone in
                                        Text(microphone.name).tag(Optional(microphone.id))
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 230)

                                Button {
                                    refreshMicrophones()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .help("Refresh microphones")
                            }
                        }

                    }
                }

                SettingsCard("Permissions", subtitle: "EchoV needs microphone access to listen, accessibility access to paste, and startup enabled to be ready after login.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "mic.fill",
                            title: "Microphone",
                            subtitle: microphoneHelpText
                        ) {
                            HStack(spacing: 8) {
                                StatusBadge(text: microphoneStatus.text, tone: microphoneStatus.tone)
                                Button("Request") {
                                    requestMicrophoneAccess()
                                }
                                .disabled(container.permissionState.microphoneAuthorizationStatus == .authorized)
                            }
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "cursorarrow.motionlines",
                            title: "Accessibility",
                            subtitle: "Allows EchoV to paste the transcript into the active app."
                        ) {
                            HStack(spacing: 8) {
                                StatusBadge(text: accessibilityStatus.text, tone: accessibilityStatus.tone)
                                Button("Open") {
                                    container.promptForAccessibilityAccess()
                                }
                                .disabled(container.permissionState.isAccessibilityTrusted)
                            }
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "power.circle.fill",
                            title: "Start at login",
                            subtitle: startupHelpText
                        ) {
                            HStack(spacing: 8) {
                                StatusBadge(text: startupStatus.text, tone: startupStatus.tone)
                                Toggle("", isOn: startsAtLoginBinding)
                                    .labelsHidden()
                                    .disabled(!canChangeStartupStatus)
                            }
                        }
                    }
                }

                SettingsCard("Output & Storage", subtitle: "Control where dictated text goes and what EchoV keeps afterward.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "doc.on.clipboard",
                            title: "Clipboard",
                            subtitle: container.settings.clipboardInsertionMode.subtitle
                        ) {
                            Picker("", selection: Bindable(container.settings).clipboardInsertionMode) {
                                ForEach(ClipboardInsertionMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 230)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "text.bubble",
                            title: "Store transcript history",
                            subtitle: "Keep transcripts locally on this Mac."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).isHistoryEnabled)
                                .labelsHidden()
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "trash",
                            title: "Delete temporary audio",
                            subtitle: "Remove captured audio after transcription completes."
                        ) {
                            Toggle("", isOn: Bindable(container.settings).shouldDeleteTemporaryAudio)
                                .labelsHidden()
                        }
                    }
                }
            }
            .padding(24)
        }
        .settingsPageBackground()
        .onAppear {
            container.refreshPermissions()
            refreshMicrophones()
        }
        .sheet(item: $hotkeyBeingRecorded) { editableHotkey in
            HotkeyRecorderSheet(
                title: "Set \(editableHotkey.title)",
                onCancel: {
                    hotkeyBeingRecorded = nil
                },
                onCapture: { binding in
                    setHotkey(binding, for: editableHotkey)
                    hotkeyBeingRecorded = nil
                }
            )
        }
    }

    private func hotkeyRow(
        editableHotkey: EditableHotkey,
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        let binding = hotkey(for: editableHotkey)

        return SettingsRow(
            icon: icon,
            title: title,
            subtitle: subtitle
        ) {
            HStack(spacing: 8) {
                KeyboardShortcutChip(text: binding?.displayName ?? "Not set")

                Button("Change") {
                    hotkeyBeingRecorded = editableHotkey
                }

                Button("Clear") {
                    setHotkey(nil, for: editableHotkey)
                }
                .disabled(binding == nil)
            }
        }
    }

    private func hotkey(for editableHotkey: EditableHotkey) -> HotkeyBinding? {
        switch editableHotkey {
        case .toggle:
            container.settings.toggleHotkey
        case .pushToTalk:
            container.settings.pushToTalkHotkey
        }
    }

    private func setHotkey(_ binding: HotkeyBinding?, for editableHotkey: EditableHotkey) {
        switch editableHotkey {
        case .toggle:
            container.setToggleHotkey(binding)
        case .pushToTalk:
            container.setPushToTalkHotkey(binding)
        }
    }

    private var microphoneSelectionSubtitle: String {
        guard let selectedID = container.settings.selectedMicrophoneDeviceID else {
            return "Use the current macOS default input device."
        }

        if let microphone = microphones.first(where: { $0.id == selectedID }) {
            return "Use \(microphone.name) for new recordings."
        }

        return "The selected microphone is not currently available."
    }

    private func refreshMicrophones() {
        microphones = container.availableMicrophones()
        if
            let selectedID = container.settings.selectedMicrophoneDeviceID,
            !microphones.contains(where: { $0.id == selectedID })
        {
            container.setSelectedMicrophoneDeviceID(nil)
        }
    }

    private var microphoneStatus: (text: String, tone: StatusBadge.Tone) {
        switch container.permissionState.microphoneAuthorizationStatus {
        case .authorized:
            ("Allowed", .success)
        case .denied, .restricted:
            ("Denied", .danger)
        case .notDetermined:
            ("Not requested", .warning)
        @unknown default:
            ("Unknown", .warning)
        }
    }

    private var microphoneHelpText: String {
        switch container.permissionState.microphoneAuthorizationStatus {
        case .authorized:
            "Ready to capture dictation audio."
        case .denied, .restricted:
            "Enable access in System Settings to record."
        case .notDetermined:
            "Permission has not been requested yet."
        @unknown default:
            "Permission status is unavailable."
        }
    }

    private var accessibilityStatus: (text: String, tone: StatusBadge.Tone) {
        container.permissionState.isAccessibilityTrusted
            ? ("Allowed", .success)
            : ("Needed", .warning)
    }

    private var startupStatus: (text: String, tone: StatusBadge.Tone) {
        switch container.permissionState.startupStatus {
        case .enabled:
            ("Enabled", .success)
        case .notRegistered:
            ("Off", .warning)
        case .requiresApproval:
            ("Needs approval", .warning)
        case .unavailable:
            ("Unavailable", .danger)
        }
    }

    private var startupHelpText: String {
        switch container.permissionState.startupStatus {
        case .enabled(.serviceManagement):
            "EchoV will open automatically when you log in."
        case .enabled(.launchAgent):
            "EchoV will open at login using a local LaunchAgent."
        case .notRegistered:
            "Open EchoV automatically when you log in."
        case .requiresApproval:
            "Approve EchoV in System Settings > General > Login Items."
        case .unavailable:
            "Startup status is unavailable."
        }
    }

    private var startsAtLoginBinding: Binding<Bool> {
        Binding(
            get: {
                if case .enabled = container.permissionState.startupStatus {
                    return true
                }

                return false
            },
            set: { container.setStartsAtLogin($0) }
        )
    }

    private var canChangeStartupStatus: Bool {
        switch container.permissionState.startupStatus {
        case .enabled, .notRegistered:
            true
        case .requiresApproval, .unavailable:
            false
        }
    }

    private func requestMicrophoneAccess() {
        Task {
            await container.requestMicrophoneAccess()
        }
    }
}

private enum EditableHotkey: String, Identifiable {
    case toggle
    case pushToTalk

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .toggle:
            "Toggle hotkey"
        case .pushToTalk:
            "Push to talk"
        }
    }

}

private struct HotkeyRecorderSheet: View {
    let title: String
    let onCancel: () -> Void
    let onCapture: (HotkeyBinding) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.headline)

            HotkeyRecorderView(onCancel: onCancel, onCapture: onCapture)
                .frame(width: 320, height: 92)

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(width: 380)
    }
}

private struct HotkeyRecorderView: NSViewRepresentable {
    let onCancel: () -> Void
    let onCapture: (HotkeyBinding) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        HotkeyRecorderNSView(onCancel: onCancel, onCapture: onCapture)
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.onCancel = onCancel
        nsView.onCapture = onCapture
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class HotkeyRecorderNSView: NSView {
    var onCancel: () -> Void
    var onCapture: (HotkeyBinding) -> Void

    init(
        onCancel: @escaping () -> Void,
        onCapture: @escaping (HotkeyBinding) -> Void
    ) {
        self.onCancel = onCancel
        self.onCapture = onCapture
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.borderWidth = 1
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        let isLightMode = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua

        layer?.borderColor = NSColor.separatorColor
            .withAlphaComponent(isLightMode ? 0.22 : 0.5)
            .cgColor
        layer?.backgroundColor = isLightMode
            ? NSColor.white.cgColor
            : NSColor.quaternaryLabelColor.withAlphaComponent(0.08).cgColor
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let text = "Press a key combination"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2
        )
        text.draw(at: point, withAttributes: attributes)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
            return
        }

        onCapture(HotkeyBinding(event: event))
    }
}

private extension HotkeyBinding {
    init(event: NSEvent) {
        let modifiers = Modifiers(eventModifierFlags: event.modifierFlags)
        let keyName = Self.displayName(for: event)
        let modifierNames = modifiers.displayNames
        let displayName = (modifierNames + [keyName]).joined(separator: " + ")

        self.init(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            displayName: displayName
        )
    }

    private static func displayName(for event: NSEvent) -> String {
        switch event.keyCode {
        case 36:
            "Return"
        case 48:
            "Tab"
        case 49:
            "Space"
        case 51:
            "Delete"
        case 53:
            "Escape"
        case 123:
            "Left Arrow"
        case 124:
            "Right Arrow"
        case 125:
            "Down Arrow"
        case 126:
            "Up Arrow"
        default:
            normalizedCharacterName(for: event)
        }
    }

    private static func normalizedCharacterName(for event: NSEvent) -> String {
        let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let characters, !characters.isEmpty else {
            return "Key \(event.keyCode)"
        }

        return characters.count == 1 ? characters.uppercased() : characters
    }
}

private extension HotkeyBinding.Modifiers {
    init(eventModifierFlags: NSEvent.ModifierFlags) {
        var modifiers: Self = []

        if eventModifierFlags.contains(.command) {
            modifiers.insert(.command)
        }

        if eventModifierFlags.contains(.option) {
            modifiers.insert(.option)
        }

        if eventModifierFlags.contains(.control) {
            modifiers.insert(.control)
        }

        if eventModifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }

        self = modifiers
    }

    var displayNames: [String] {
        var names: [String] = []

        if contains(.command) {
            names.append("Command")
        }

        if contains(.option) {
            names.append("Option")
        }

        if contains(.control) {
            names.append("Control")
        }

        if contains(.shift) {
            names.append("Shift")
        }

        return names
    }
}
