import SwiftUI

struct SettingsRootView: View {
    @State private var selection: SettingsSection = .status
    @State private var isSidebarVisible = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        isSidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderless)
                .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")

                Text(selection.title)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(.bar)
            .overlay(alignment: .bottom) {
                DividerLine()
            }

            HStack(spacing: 0) {
                if isSidebarVisible {
                    SettingsSidebar(selection: $selection)
                        .frame(width: 190)
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Rectangle()
                        .fill(.separator.opacity(0.55))
                        .frame(width: 1)
                }

                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 780, height: 540)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .status:
            StatusOverviewView()
        case .dictation:
            GeneralSettingsView()
        case .model:
            TranscriptionSettingsView()
        case .history:
            HistoryView()
        case .licenses:
            LicensesView()
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .font(.body)
                        .foregroundStyle(selection == section ? .primary : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background {
                            if selection == section {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.16))
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case status
    case dictation
    case model
    case history
    case licenses

    var id: String { rawValue }

    var title: String {
        switch self {
        case .status:
            "Status"
        case .dictation:
            "Dictation"
        case .model:
            "Model"
        case .history:
            "History"
        case .licenses:
            "Licenses"
        }
    }

    var systemImage: String {
        switch self {
        case .status:
            "gauge.with.dots.needle.bottom.50percent"
        case .dictation:
            "mic"
        case .model:
            "waveform.badge.magnifyingglass"
        case .history:
            "clock"
        case .licenses:
            "doc.text"
        }
    }
}
