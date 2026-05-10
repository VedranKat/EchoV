import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder var content: Content

    init(
        _ title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 3) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator.opacity(0.35))
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            trailing
        }
        .frame(minHeight: 36)
    }
}

struct StatusBadge: View {
    enum Tone {
        case neutral
        case success
        case warning
        case danger
        case active

        var color: Color {
            switch self {
            case .neutral:
                .secondary
            case .success:
                .green
            case .warning:
                .orange
            case .danger:
                .red
            case .active:
                .accentColor
            }
        }
    }

    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tone.color.opacity(0.14), in: Capsule())
    }
}

struct KeyboardShortcutChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .monospaced).weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.separator.opacity(0.45))
            }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle.weight(.semibold))

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(.separator.opacity(0.55))
            .frame(height: 1)
    }
}
