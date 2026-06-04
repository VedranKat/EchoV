import AppKit
import SwiftUI

@MainActor
final class LiveSubtitleWindowController {
    private let container: AppContainer
    private var window: NSPanel?
    private var observerID: UUID?

    init(container: AppContainer) {
        self.container = container
        self.observerID = container.liveSubtitles.addObserver { [weak self] in
            self?.syncWindowVisibility()
        }
        syncWindowVisibility()
    }

    deinit {
        if let observerID {
            Task { @MainActor [container] in
                container.liveSubtitles.removeObserver(observerID)
            }
        }
    }

    private func syncWindowVisibility() {
        guard container.liveSubtitles.hasVisibleSubtitle else {
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
        window.orderFrontRegardless()
    }

    private func makeWindow() -> NSPanel {
        let rootView = LiveSubtitleOverlayView()
            .environment(container)
            .environment(container.liveSubtitles)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(rootView: rootView)
        position(panel)
        return panel
    }

    private func position(_ window: NSWindow) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(origin: .zero, size: windowSize)
        let size = windowSize(for: visibleFrame)
        let origin = NSPoint(
            x: visibleFrame.midX - (size.width / 2),
            y: visibleFrame.minY + CGFloat(container.settings.liveSubtitleBottomMargin)
        )
        window.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private var windowSize: NSSize {
        windowSize(for: NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 600))
    }

    private func windowSize(for visibleFrame: NSRect) -> NSSize {
        let width = min(max(520, visibleFrame.width - 120), 980)
        let textSize = CGFloat(container.settings.liveSubtitleTextSize)
        let lines = CGFloat(container.settings.liveSubtitleMaxLines)
        let height = max(74, min(190, 28 + (textSize + 11) * lines))
        return NSSize(width: width, height: height)
    }
}

private struct LiveSubtitleOverlayView: View {
    @Environment(AppContainer.self) private var container
    @Environment(LiveSubtitleStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            statusDot

            VStack(alignment: .center, spacing: 5) {
                ForEach(visibleLines) { line in
                    Text(line.text)
                        .font(.system(size: currentTextSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity, alignment: .bottom)

            statusDot.opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.74))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14))
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
            .help(statusHelp)
    }

    private var statusColor: Color {
        if store.isCatchingUp {
            return .orange
        }

        if store.isPostProcessing {
            return .blue
        }

        return store.isCurrentTextFinal ? .green : .white.opacity(0.7)
    }

    private var statusHelp: String {
        if store.isCatchingUp {
            return "Catching up with raw captions"
        }

        if store.isPostProcessing {
            return "Prime is processing"
        }

        return store.isCurrentTextFinal ? "Final subtitle" : "Raw subtitle"
    }

    private var currentTextSize: CGFloat {
        CGFloat(container.settings.liveSubtitleTextSize)
    }

    private var visibleLines: [VisibleLiveSubtitleLine] {
        Array(store.visibleLines.suffix(max(1, container.settings.liveSubtitleMaxLines)))
    }
}
