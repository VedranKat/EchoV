import SwiftUI

struct VoiceModeBackendIndicator: View {
    enum Style {
        case regular
        case compact
    }

    let title: String
    let subtitle: String
    let isCloud: Bool
    var style: Style = .regular

    var body: some View {
        HStack(spacing: style == .compact ? 5 : 8) {
            Image(systemName: isCloud ? "cloud" : "desktopcomputer")
                .font(.system(size: style == .compact ? 11 : 13, weight: .semibold))

            if style == .compact {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            } else {
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
        }
        .foregroundStyle(isCloud ? .orange : .green)
        .padding(.horizontal, style == .compact ? 7 : 10)
        .padding(.vertical, style == .compact ? 4 : 6)
        .background(
            (isCloud ? Color.orange : Color.green).opacity(0.13),
            in: RoundedRectangle(cornerRadius: style == .compact ? 6 : 8, style: .continuous)
        )
    }
}
