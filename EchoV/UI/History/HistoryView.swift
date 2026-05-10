import SwiftUI

struct HistoryView: View {
    @Environment(AppContainer.self) private var container
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(
                    title: "History",
                    subtitle: "Browse transcripts stored locally on this Mac."
                )

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Search transcripts", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button(role: .destructive) {
                        Task {
                            await container.historyStore.clear()
                        }
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(container.historyStore.items.isEmpty)
                }

                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No transcripts yet" : "No matching transcripts",
                        systemImage: searchText.isEmpty ? "text.bubble" : "magnifyingglass"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 72)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            HistoryRow(item: item)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var filteredItems: [TranscriptHistoryItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return container.historyStore.items
        }

        return container.historyStore.items.filter {
            $0.snippet.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private struct HistoryRow: View {
    let item: TranscriptHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.snippet)
                .font(.body)
                .lineLimit(4)
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Label(item.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                Text("\(item.characterCount) characters")

                if let duration = item.duration {
                    Text(durationText(duration))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let seconds = Int(duration.rounded())
        return "\(seconds)s"
    }
}
