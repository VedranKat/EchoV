import SwiftUI

struct HistoryView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Local Transcript History")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    Task {
                        await container.historyStore.clear()
                    }
                }
                .disabled(container.historyStore.items.isEmpty)
            }

            if container.historyStore.items.isEmpty {
                ContentUnavailableView("No transcripts yet", systemImage: "text.bubble")
            } else {
                List(container.historyStore.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.snippet)
                            .lineLimit(3)
                        Text("\(item.createdAt.formatted(date: .abbreviated, time: .shortened)) • \(item.characterCount) characters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}
