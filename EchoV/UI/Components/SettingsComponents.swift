import SwiftUI

enum SettingsTheme {
    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color(red: 0.976, green: 0.980, blue: 0.986)
            : Color(nsColor: .windowBackgroundColor)
    }

    static func sidebarBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color(red: 0.918, green: 0.934, blue: 0.954)
            : Color(nsColor: .controlBackgroundColor)
    }

    static func toolbarBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color(red: 0.936, green: 0.948, blue: 0.965)
            : Color(nsColor: .windowBackgroundColor)
    }

    static func controlFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color(red: 0.929, green: 0.941, blue: 0.957)
            : Color(nsColor: .quaternaryLabelColor).opacity(0.8)
    }

    static func selectedSidebarFill(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color.accentColor.opacity(0.18)
            : Color.accentColor.opacity(0.16)
    }

    static func cardShadow(for colorScheme: ColorScheme) -> Color {
        colorScheme == .light
            ? Color(red: 0.365, green: 0.455, blue: 0.580).opacity(0.10)
            : .clear
    }

    static func separatorOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .light ? 0.18 : 0.35
    }
}

private struct SettingsPageBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background(SettingsTheme.pageBackground(for: colorScheme))
    }
}

extension View {
    func settingsPageBackground() -> some View {
        modifier(SettingsPageBackgroundModifier())
    }
}

struct SettingsCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme

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
        .background {
            let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

            if colorScheme == .light {
                shape.fill(Color.white)
            } else {
                shape.fill(.regularMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator.opacity(SettingsTheme.separatorOpacity(for: colorScheme)))
        }
        .shadow(
            color: SettingsTheme.cardShadow(for: colorScheme),
            radius: colorScheme == .light ? 12 : 0,
            x: 0,
            y: colorScheme == .light ? 5 : 0
        )
    }
}

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    @ViewBuilder var trailing: Trailing
    @Environment(\.colorScheme) private var colorScheme

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
                .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.system(.callout, design: .monospaced).weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(.separator.opacity(colorScheme == .light ? 0.22 : 0.45))
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

struct SetupHelpButton: View {
    let title: String
    let message: String

    @State private var isShowingHelp = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            isShowingHelp.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .background(SettingsTheme.controlFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .help(title)
        .onHover { isHovering in
            isShowingHelp = isHovering
        }
        .popover(isPresented: $isShowingHelp, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 300, alignment: .leading)
        }
    }
}
