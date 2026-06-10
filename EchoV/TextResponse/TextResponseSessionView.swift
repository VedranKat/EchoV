import AppKit
import SwiftUI

struct TextResponseSessionView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme
    @State private var draft = ""
    @FocusState private var isComposerFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            sessionSidebar

            Divider()

            VStack(spacing: 0) {
                if let session = container.textResponseSessions.selectedSession {
                    chatView(for: session)
                } else {
                    ContentUnavailableView("No chats", systemImage: "bubble.left.and.bubble.right")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SettingsTheme.pageBackground(for: colorScheme))
        }
        .frame(minWidth: 760, minHeight: 520)
        .onChange(of: container.textResponseSessions.selectedSessionID) { _, _ in
            draft = ""
            isComposerFocused = true
        }
    }

    private var sessionSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chats")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("\(container.textResponseSessions.sessions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(SettingsTheme.controlFill(for: colorScheme), in: Capsule())
            }
            .padding(.horizontal, 14)
            .frame(height: 48)

            Divider()

            if container.textResponseSessions.sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("No chats")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Bindable(container.textResponseSessions).selectedSessionID) {
                    ForEach(container.textResponseSessions.sessions) { session in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(session.title)
                                .font(.callout.weight(.semibold))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 6) {
                                Text(session.kind.displayName)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(SettingsTheme.controlFill(for: colorScheme), in: Capsule())

                                Image(systemName: session.isGenerating ? "sparkles" : "clock")
                                    .font(.caption2)

                                Text(session.isGenerating ? "Thinking" : session.updatedAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 5)
                        .tag(Optional(session.id))
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .background(SettingsTheme.sidebarBackground(for: colorScheme))
        .frame(width: 240)
    }

    private func chatView(for session: TextResponseSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(session.title)
                            .font(.headline)
                            .lineLimit(1)

                        Text(session.kind.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(SettingsTheme.controlFill(for: colorScheme), in: Capsule())
                    }

                    Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if session.isGenerating {
                    StatusBadge(text: "Thinking", tone: .active)
                }

                let backend = container.voiceModeBackendIndicator()
                VoiceModeBackendIndicator(
                    title: backend.title,
                    subtitle: backend.subtitle,
                    isCloud: backend.isCloud
                )

                TextResponseChatCopyButton(
                    transcript: TextResponseTranscriptFormatter.transcript(for: session)
                )
            }
            .padding(.horizontal, 20)
            .frame(height: 58)
            .background(SettingsTheme.toolbarBackground(for: colorScheme))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(session.messages) { message in
                            TextResponseMessageBubble(message: message)
                                .id(TextResponseScrollTarget.message(message.id))
                        }

                        if session.isGenerating {
                            TextResponseThinkingRow()
                                .id(TextResponseScrollTarget.thinking)
                        }

                        if let lastError = session.lastError {
                            TextResponseErrorRow(message: lastError)
                                .id(TextResponseScrollTarget.error)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onAppear {
                    scrollToEnd(proxy: proxy, session: session)
                    isComposerFocused = true
                }
                .onChange(of: session.messages.count) { _, _ in
                    scrollToEnd(proxy: proxy, session: session)
                }
                .onChange(of: session.streamedCharacterCount) { _, _ in
                    scrollToEnd(proxy: proxy, session: session)
                }
                .onChange(of: session.isGenerating) { _, _ in
                    scrollToEnd(proxy: proxy, session: session)
                }
            }

            Divider()

            HStack(spacing: 10) {
                TextField("Reply", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.separator.opacity(SettingsTheme.separatorOpacity(for: colorScheme)))
                    }
                    .disabled(session.isGenerating)
                    .focused($isComposerFocused)
                    .onSubmit {
                        sendReply(sessionID: session.id, isGenerating: session.isGenerating)
                    }

                Button {
                    sendReply(sessionID: session.id, isGenerating: session.isGenerating)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.isGenerating || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(SettingsTheme.toolbarBackground(for: colorScheme))
        }
    }

    private func sendReply(sessionID: UUID, isGenerating: Bool) {
        guard !isGenerating else {
            return
        }

        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }

        draft = ""
        Task {
            await container.continueTextResponseSession(sessionID: sessionID, userText: text)
        }
    }

    private func scrollToEnd(proxy: ScrollViewProxy, session: TextResponseSession) {
        Task { @MainActor in
            if session.isGenerating {
                proxy.scrollTo(TextResponseScrollTarget.thinking, anchor: .bottom)
            } else if session.lastError != nil {
                proxy.scrollTo(TextResponseScrollTarget.error, anchor: .bottom)
            } else if let lastID = session.messages.last?.id {
                proxy.scrollTo(TextResponseScrollTarget.message(lastID), anchor: .bottom)
            }
        }
    }

}

private enum TextResponseScrollTarget: Hashable {
    case message(UUID)
    case thinking
    case error
}

private extension TextResponseSessionKind {
    var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .voice:
            return "Voice"
        }
    }
}

private struct TextResponseMessageBubble: View {
    let message: TextResponseMessage
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .bottom) {
            if message.role == .user {
                Spacer(minLength: 32)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 5) {
                messageHeader

                if !message.reasoning.isEmpty {
                    DisclosureGroup {
                        MarkdownMessageView(content: message.reasoning, style: .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    } label: {
                        Label("Thinking", systemImage: "brain")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .frame(maxWidth: 620, alignment: .leading)
                }

                if !message.text.isEmpty || !message.isStreaming {
                    messageContent(message.text.isEmpty ? "No response text." : message.text)
                }

                if let streamError = message.streamError {
                    TextResponseErrorRow(message: streamError)
                }
            }
            .frame(maxWidth: 620, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant {
                Spacer(minLength: 32)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var copyableText: String? {
        message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message.text
    }

    private var copyActionTitle: String {
        switch message.role {
        case .user:
            "Copy message"
        case .assistant:
            "Copy response"
        }
    }

    private var messageHeader: some View {
        HStack(spacing: 6) {
            if message.role == .user, let copyableText {
                TextResponseMessageCopyButton(
                    text: copyableText,
                    title: copyActionTitle
                )
            }

            Text(message.role == .user ? "You" : "EchoV")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            if message.role == .assistant, let copyableText {
                TextResponseMessageCopyButton(
                    text: copyableText,
                    title: copyActionTitle
                )
            }
        }
    }

    @ViewBuilder
    private func messageContent(_ text: String) -> some View {
        if message.role == .user {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contextMenu {
                    copyContextMenu()
                }
        } else {
            MarkdownMessageView(content: text)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator.opacity(SettingsTheme.separatorOpacity(for: colorScheme)))
                }
                .contextMenu {
                    copyContextMenu()
                }
        }
    }

    @ViewBuilder
    private func copyContextMenu() -> some View {
        if let copyableText {
            Button {
                TextResponseClipboard.copy(copyableText)
            } label: {
                Label(copyActionTitle.capitalized, systemImage: "doc.on.doc")
            }
        }
    }

    private var background: Color {
        switch message.role {
        case .user:
            .accentColor
        case .assistant:
            colorScheme == .light ? .white : Color(nsColor: .controlBackgroundColor)
        }
    }
}

private struct TextResponseMessageCopyButton: View {
    let text: String
    let title: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        Button {
            TextResponseClipboard.copy(text)
            didCopy = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1_200))
                didCopy = false
            }
        } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(didCopy ? .green : .secondary)
        .background(buttonBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help(didCopy ? "Copied" : title)
        .onHover { isHovering = $0 }
    }

    private var buttonBackground: Color {
        guard isHovering || didCopy else {
            return .clear
        }

        return SettingsTheme.controlFill(for: colorScheme)
    }
}

enum TextResponseClipboard {
    static func copy(_ text: String, pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

enum TextResponseTranscriptFormatter {
    static func transcript(for session: TextResponseSession) -> String? {
        var sections: [String] = []
        for message in session.messages {
            let trimmedText = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedReasoning = message.reasoning.trimmingCharacters(in: .whitespacesAndNewlines)

            if !trimmedReasoning.isEmpty {
                sections.append("EchoV thinking:\n\(trimmedReasoning)")
            }

            guard !trimmedText.isEmpty else {
                continue
            }

            switch message.role {
            case .user:
                sections.append("You:\n\(message.text)")
            case .assistant:
                sections.append("EchoV:\n\(message.text)")
            }
        }

        if let lastError = session.lastError?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lastError.isEmpty
        {
            sections.append("Error:\n\(lastError)")
        }

        let transcript = sections.joined(separator: "\n\n")
        return transcript.isEmpty ? nil : transcript
    }
}

private struct TextResponseChatCopyButton: View {
    let transcript: String?

    @Environment(\.colorScheme) private var colorScheme
    @State private var didCopy = false

    var body: some View {
        Button {
            guard let transcript else {
                return
            }

            TextResponseClipboard.copy(transcript)
            didCopy = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1_200))
                didCopy = false
            }
        } label: {
            Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 10)
                .frame(height: 28)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(didCopy ? .green : .primary)
        .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.separator.opacity(SettingsTheme.separatorOpacity(for: colorScheme)))
        }
        .disabled(transcript == nil)
        .opacity(transcript == nil ? 0.55 : 1)
        .help(didCopy ? "Copied chat" : "Copy chat")
    }
}

private extension TextResponseSession {
    var streamedCharacterCount: Int {
        messages.reduce(0) { partialResult, message in
            partialResult + message.text.count + message.reasoning.count
        }
    }
}

private struct TextResponseThinkingRow: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text("Thinking")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer(minLength: 32)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TextResponseErrorRow: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
