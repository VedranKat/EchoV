import SwiftUI

struct VoiceModeBackendIndicator: View {
    let title: String
    let subtitle: String
    let isCloud: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCloud ? "cloud" : "desktopcomputer")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .foregroundStyle(isCloud ? .orange : .green)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((isCloud ? Color.orange : Color.green).opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
