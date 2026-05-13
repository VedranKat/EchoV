import SwiftUI

struct LicensesView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Licenses",
                    subtitle: "Third-party notices for dependencies used by EchoV. Full notices are included in THIRD_PARTY_NOTICES.md."
                )

                LazyVStack(spacing: 12) {
                    ForEach(container.licensesStore.notices) { notice in
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(notice.name)
                                            .font(.headline)

                                        Text(notice.licenseName)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "doc.text")
                                        .foregroundStyle(.secondary)
                                }

                                Text(notice.notice)
                                    .font(.body)
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
