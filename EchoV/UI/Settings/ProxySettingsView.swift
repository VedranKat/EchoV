import SwiftUI

struct ProxySettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        @Bindable var settings = container.settings

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "Proxy",
                    subtitle: "Route managed model and runtime downloads through corporate HTTP and HTTPS proxies."
                )

                SettingsCard("Connection Proxy", subtitle: "Local llama-server requests always stay direct on 127.0.0.1.") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "network",
                            title: "Use proxy",
                            subtitle: settings.proxySettings.validationMessage
                        ) {
                            Toggle("", isOn: $settings.isProxyEnabled)
                                .labelsHidden()
                        }

                        DividerLine()

                        proxyRow(
                            icon: "arrow.down.circle",
                            title: "HTTP proxy",
                            subtitle: "Used for HTTP download requests.",
                            host: $settings.httpProxyHost,
                            port: $settings.httpProxyPort,
                            isEnabled: settings.isProxyEnabled
                        )

                        DividerLine()

                        SettingsRow(
                            icon: "lock.circle",
                            title: "Use HTTP proxy for HTTPS",
                            subtitle: "Most corporate proxies use the same host and port for both."
                        ) {
                            Toggle("", isOn: $settings.usesSameProxyForHTTPS)
                                .labelsHidden()
                                .disabled(!settings.isProxyEnabled)
                        }

                        if !settings.usesSameProxyForHTTPS {
                            DividerLine()

                            proxyRow(
                                icon: "lock.shield",
                                title: "HTTPS proxy",
                                subtitle: "Used for HTTPS download requests.",
                                host: $settings.httpsProxyHost,
                                port: $settings.httpsProxyPort,
                                isEnabled: settings.isProxyEnabled
                            )
                        }
                    }
                }

                SettingsCard("Download Coverage") {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "shippingbox",
                            title: "Managed downloads",
                            subtitle: "Parakeet, Gemma, and llama.cpp downloads use these settings."
                        ) {
                            StatusBadge(text: settings.isProxyEnabled ? "Proxy" : "Direct", tone: settings.isProxyEnabled ? .active : .neutral)
                        }

                        DividerLine()

                        SettingsRow(
                            icon: "cpu",
                            title: "Local cleanup server",
                            subtitle: "Gemma post-processing talks to llama-server directly on this Mac."
                        ) {
                            StatusBadge(text: "Direct", tone: .success)
                        }
                    }
                }
            }
            .padding(24)
        }
        .settingsPageBackground()
    }

    private func proxyRow(
        icon: String,
        title: String,
        subtitle: String,
        host: Binding<String>,
        port: Binding<String>,
        isEnabled: Bool
    ) -> some View {
        SettingsRow(
            icon: icon,
            title: title,
            subtitle: subtitle
        ) {
            HStack(spacing: 8) {
                TextField("proxy.example.com", text: host)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)
                    .disabled(!isEnabled)

                TextField("Port", text: port)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .disabled(!isEnabled)
            }
        }
    }
}
