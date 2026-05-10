import SwiftUI

struct SettingsRootView: View {
    @State private var selection: SettingsSection? = .status

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            Group {
                switch selection ?? .status {
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
            .navigationTitle((selection ?? .status).title)
        }
        .frame(width: 780, height: 540)
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
