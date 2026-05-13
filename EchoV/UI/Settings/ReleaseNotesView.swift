import SwiftUI

struct ReleaseNotesView: View {
    private let notes = ReleaseNote.all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Release Notes",
                    subtitle: "Small notes for each EchoV release."
                )

                LazyVStack(spacing: 12) {
                    ForEach(notes) { note in
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(note.version)
                                        .font(.headline)

                                    Spacer()

                                    if let date = note.date {
                                        Text(date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text(note.summary)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .settingsPageBackground()
    }
}

private struct ReleaseNote: Identifiable {
    let version: String
    let date: String?
    let summary: String

    var id: String { version }

    static let all: [ReleaseNote] = [
        ReleaseNote(
            version: "v1.1.0",
            date: nil,
            summary: "Adds microphone selection and three post-processing levels, with a leaner Llama server lifecycle to reduce RAM usage plus light mode color and interface polish."
        ),
        ReleaseNote(
            version: "v1.0.0",
            date: nil,
            summary: "First local-first macOS dictation release with global shortcuts, local transcription, optional text cleanup, transcript history, proxy settings, and bundled license notices."
        )
    ]
}
