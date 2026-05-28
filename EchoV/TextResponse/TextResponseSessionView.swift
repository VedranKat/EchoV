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
                    ContentUnavailableView("No text responses", systemImage: "text.bubble")
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
                Text("Text Responses")
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
                    Image(systemName: "text.bubble")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("No sessions")
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
                    Text(session.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if session.isGenerating {
                    StatusBadge(text: "Thinking", tone: .active)
                }

                Button {
                    copyLatestAssistantMessage(from: session)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(latestAssistantMessage(in: session) == nil)
                .help("Copy latest response")
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

    private func copyLatestAssistantMessage(from session: TextResponseSession) {
        guard let text = latestAssistantMessage(in: session)?.text else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func latestAssistantMessage(in session: TextResponseSession) -> TextResponseMessage? {
        session.messages.last { message in
            message.role == .assistant
        }
    }
}

private enum TextResponseScrollTarget: Hashable {
    case message(UUID)
    case thinking
    case error
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
                Text(message.role == .user ? "You" : "EchoV")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

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
        } else {
            MarkdownMessageView(content: text)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator.opacity(SettingsTheme.separatorOpacity(for: colorScheme)))
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
