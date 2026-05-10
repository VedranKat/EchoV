import SwiftUI

struct SettingsRootView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }

            TranscriptionSettingsView()
                .tabItem { Label("Transcription", systemImage: "waveform") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }

            LicensesView()
                .tabItem { Label("Licenses", systemImage: "doc.text") }
        }
        .frame(width: 620, height: 420)
    }
}
