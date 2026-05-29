import AppKit
import SwiftUI

@MainActor
final class VoiceModeHUDWindowController {
    private enum Metrics {
        static let windowSize = NSSize(width: 380, height: 62)
        static let margin: CGFloat = 18
    }

    private let container: AppContainer
    private var window: NSPanel?
    private var observerID: UUID?
    private var hideTask: Task<Void, Never>?
    private var isTrackingVoiceModeInteraction = false

    init(container: AppContainer) {
        self.container = container
        self.observerID = container.appState.addStatusObserver { [weak self] in
            self?.syncWindowVisibility()
        }
        syncWindowVisibility()
    }

    deinit {
        hideTask?.cancel()
        if let observerID {
            Task { @MainActor [container] in
                container.appState.removeStatusObserver(observerID)
            }
        }
    }

    private func syncWindowVisibility() {
        hideTask?.cancel()
        hideTask = nil

        guard container.settings.isVoiceModeHUDEnabled, currentHUDState() != nil else {
            window?.orderOut(nil)
            return
        }

        if window == nil {
            window = makeWindow()
        }

        guard let window else {
            return
        }

        window.orderFrontRegardless()

        if isTerminalState {
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run {
                    self?.window?.orderOut(nil)
                    self?.isTrackingVoiceModeInteraction = false
                }
            }
        }
    }

    private func makeWindow() -> NSPanel {
        let rootView = VoiceModeHUDView()
            .environment(container)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Metrics.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(rootView: rootView)
        position(panel)
        return panel
    }

    private func position(_ window: NSWindow) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(origin: .zero, size: Metrics.windowSize)
        let origin = NSPoint(
            x: visibleFrame.maxX - Metrics.windowSize.width - Metrics.margin,
            y: visibleFrame.maxY - Metrics.windowSize.height - Metrics.margin
        )
        window.setFrame(NSRect(origin: origin, size: Metrics.windowSize), display: false)
    }

    private func currentHUDState() -> DictationState? {
        if container.appState.voiceModePromptPreview != nil {
            isTrackingVoiceModeInteraction = true
            return container.appState.state
        }

        switch container.appState.state {
        case .voiceModeWakeListening,
             .voiceModeCheckingWakePhrase,
             .voiceModePromptListening,
             .voiceModePromptRecording,
             .voiceModeThinking,
             .voiceModeSpeaking:
            isTrackingVoiceModeInteraction = true
            return container.appState.state
        case .transcribing,
             .cleaning,
             .inserting,
             .failed,
             .cancelled,
             .completed:
            guard isTrackingVoiceModeInteraction else {
                return nil
            }
            return container.appState.state
        case .idle, .listening, .recording, .voiceGateRecording:
            isTrackingVoiceModeInteraction = false
            return nil
        }
    }

    private var isTerminalState: Bool {
        switch container.appState.state {
        case .failed, .cancelled, .completed:
            return true
        default:
            return false
        }
    }
}

private struct VoiceModeHUDView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 10)
                .help("Drag to move")

            ZStack {
                Circle()
                    .fill(tone.color.opacity(0.14))
                    .frame(width: 30, height: 30)

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tone.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    StatusBadge(text: badge, tone: tone)
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            let backend = container.voiceModeBackendIndicator()
            VoiceModeBackendIndicator(
                title: backend.title,
                subtitle: backend.subtitle,
                isCloud: backend.isCloud,
                style: .compact
            )

            Button {
                Task {
                    await container.stopActiveWork()
                }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .help("Stop EchoV")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(width: 380, height: 62)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator.opacity(SettingsTheme.separatorOpacity(for: colorScheme)))
        }
        .contentShape(Rectangle())
    }

    private var title: String {
        if container.appState.voiceModePromptPreview != nil {
            return "Review Prompt"
        }

        switch container.appState.state {
        case .voiceModeWakeListening:
            return "Voice Mode"
        case .voiceModeCheckingWakePhrase:
            return "Checking Command"
        case .voiceModePromptListening:
            return "Listening"
        case .voiceModePromptRecording:
            return "Recording Request"
        case .voiceModeThinking:
            return "Thinking"
        case .voiceModeSpeaking:
            return "Speaking"
        case .transcribing:
            return "Transcribing"
        case .cleaning:
            return "Cleaning"
        case .inserting:
            return "Inserting"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Stopped"
        case .idle, .listening, .recording, .voiceGateRecording:
            return "EchoV"
        }
    }

    private var detail: String {
        if let detail = container.appState.lastDetail, !detail.isEmpty {
            return detail
        }

        switch container.appState.state {
        case .voiceModeWakeListening:
            return "Listening for Computer, Computer text, Continue, or Computer cleanup."
        case .voiceModePromptListening:
            return "Say your request."
        case .voiceModePromptRecording:
            return "Listening for the end of your request."
        case .voiceModeThinking:
            return "Generating a response."
        case .voiceModeSpeaking:
            return "Playing spoken response."
        case .failed(let error):
            return error.userMessage
        case .cancelled:
            return "The active task was stopped."
        default:
            return container.appState.state.menuTitle
        }
    }

    private var icon: String {
        if container.appState.voiceModePromptPreview != nil {
            return "rectangle.and.pencil.and.ellipsis"
        }

        switch container.appState.state {
        case .voiceModeWakeListening:
            return "speaker.wave.2.bubble"
        case .voiceModeCheckingWakePhrase:
            return "text.magnifyingglass"
        case .voiceModePromptListening:
            return "captions.bubble"
        case .voiceModePromptRecording:
            return "waveform.circle"
        case .voiceModeThinking, .cleaning:
            return "cpu"
        case .voiceModeSpeaking:
            return "speaker.wave.2"
        case .transcribing:
            return "waveform"
        case .inserting:
            return "arrow.down.doc"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        case .cancelled:
            return "stop.circle"
        case .idle, .listening, .recording, .voiceGateRecording:
            return "waveform"
        }
    }

    private var badge: String {
        if container.appState.voiceModePromptPreview != nil {
            return "Preview"
        }

        switch container.appState.state {
        case .completed:
            return "Done"
        case .failed:
            return "Error"
        case .cancelled:
            return "Stopped"
        case .voiceModeSpeaking:
            return "Speaking"
        case .voiceModeWakeListening, .voiceModePromptListening:
            return "Listening"
        case .voiceModePromptRecording:
            return "Live"
        default:
            return "Working"
        }
    }

    private var tone: StatusBadge.Tone {
        switch container.appState.state {
        case .completed:
            return .success
        case .failed:
            return .danger
        case .cancelled:
            return .warning
        default:
            return .active
        }
    }
}
