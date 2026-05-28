import AppKit
import SwiftUI

@MainActor
final class VoiceModePromptPreviewWindowController {
    private let container: AppContainer
    private var window: NSWindow?
    private var windowDelegate: PreviewWindowDelegate?
    private var observerID: UUID?

    init(container: AppContainer) {
        self.container = container
        self.observerID = container.appState.addStatusObserver { [weak self] in
            self?.syncWindowVisibility()
        }
        syncWindowVisibility()
    }

    deinit {
        if let observerID {
            Task { @MainActor [container] in
                container.appState.removeStatusObserver(observerID)
            }
        }
    }

    private func syncWindowVisibility() {
        guard container.appState.voiceModePromptPreview != nil else {
            window?.orderOut(nil)
            return
        }

        if window == nil {
            window = makeWindow()
        }

        guard let window else {
            return
        }

        position(window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let rootView = VoiceModePromptPreviewView()
            .environment(container)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Review EchoV Prompt"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 540, height: 360)
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: rootView)
        let windowDelegate = PreviewWindowDelegate(container: container)
        self.windowDelegate = windowDelegate
        window.delegate = windowDelegate
        position(window)
        return window
    }

    private func position(_ window: NSWindow) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 620, height: 430)
        let margin: CGFloat = 22
        let size = NSSize(
            width: min(max(window.frame.width, window.minSize.width), visibleFrame.width - (margin * 2)),
            height: min(max(window.frame.height, window.minSize.height), visibleFrame.height - (margin * 2))
        )
        let origin = NSPoint(
            x: visibleFrame.maxX - size.width - margin,
            y: visibleFrame.maxY - size.height - margin
        )
        window.setFrame(NSRect(origin: origin, size: size), display: false)
    }
}

private final class PreviewWindowDelegate: NSObject, NSWindowDelegate {
    private weak var container: AppContainer?

    init(container: AppContainer) {
        self.container = container
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor [weak container] in
            container?.cancelVoiceModePromptPreview()
        }
        return false
    }
}

private struct VoiceModePromptPreviewView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme
    @State private var draft = ""
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        Group {
            if let request = container.appState.voiceModePromptPreview {
                content(for: request)
                    .id(request.id)
                    .onAppear {
                        draft = request.promptText
                        isEditorFocused = true
                    }
            } else {
                EmptyView()
            }
        }
        .frame(minWidth: 540, minHeight: 360)
        .background(SettingsTheme.pageBackground(for: colorScheme))
    }

    private func content(for request: VoiceModePromptPreviewRequest) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Review Prompt")
                    .font(.title2.weight(.semibold))

                StatusBadge(text: request.commandTitle, tone: .active)

                if request.includesSelectionContext {
                    StatusBadge(text: "Selection", tone: .neutral)
                }

                Spacer()

                VoiceModeBackendIndicator(
                    title: request.backendTitle,
                    subtitle: request.backendSubtitle,
                    isCloud: request.isCloudBackend
                )
            }

            TextEditor(text: $draft)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor).opacity(colorScheme == .light ? 1 : 0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator.opacity(SettingsTheme.separatorOpacity(for: colorScheme)))
                }
                .focused($isEditorFocused)

            HStack(spacing: 10) {
                Button("Cancel") {
                    container.resolveVoiceModePromptPreview(id: request.id, promptText: nil)
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Send") {
                    container.resolveVoiceModePromptPreview(id: request.id, promptText: draft)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
    }
}
