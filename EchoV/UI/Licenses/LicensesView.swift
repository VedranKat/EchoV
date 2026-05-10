import SwiftUI

struct LicensesView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        List(container.licensesStore.notices) { notice in
            VStack(alignment: .leading, spacing: 6) {
                Text(notice.name)
                    .font(.headline)
                Text(notice.licenseName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(notice.notice)
                    .font(.body)
            }
            .padding(.vertical, 6)
        }
        .padding()
    }
}
