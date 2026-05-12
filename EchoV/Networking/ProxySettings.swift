import Foundation

struct ProxySettings: Equatable, Sendable {
    var isEnabled: Bool
    var httpHost: String
    var httpPort: String
    var httpsHost: String
    var httpsPort: String
    var usesSameProxyForHTTPS: Bool

    static let disabled = ProxySettings(
        isEnabled: false,
        httpHost: "",
        httpPort: "",
        httpsHost: "",
        httpsPort: "",
        usesSameProxyForHTTPS: true
    )

    var effectiveHTTPSHost: String {
        usesSameProxyForHTTPS ? httpHost : httpsHost
    }

    var effectiveHTTPSPort: String {
        usesSameProxyForHTTPS ? httpPort : httpsPort
    }

    var isValid: Bool {
        guard isEnabled else {
            return true
        }

        return Self.normalizedHost(httpHost) != nil
            && Self.normalizedPort(httpPort) != nil
            && Self.normalizedHost(effectiveHTTPSHost) != nil
            && Self.normalizedPort(effectiveHTTPSPort) != nil
    }

    var validationMessage: String {
        guard isEnabled else {
            return "Proxy is disabled."
        }

        guard isValid else {
            return "Enter host names and ports from 1 to 65535."
        }

        return "HTTP and HTTPS downloads will use the configured proxy."
    }

    var environmentValues: [String: String] {
        guard
            isEnabled,
            let httpURL = proxyURL(scheme: "http", host: httpHost, port: httpPort),
            let httpsURL = proxyURL(scheme: "http", host: effectiveHTTPSHost, port: effectiveHTTPSPort)
        else {
            return [:]
        }

        return [
            "http_proxy": httpURL,
            "HTTP_PROXY": httpURL,
            "https_proxy": httpsURL,
            "HTTPS_PROXY": httpsURL
        ]
    }

    var connectionProxyDictionary: [String: Any]? {
        guard
            isEnabled,
            let httpHost = Self.normalizedHost(httpHost),
            let httpPort = Self.normalizedPort(httpPort),
            let httpsHost = Self.normalizedHost(effectiveHTTPSHost),
            let httpsPort = Self.normalizedPort(effectiveHTTPSPort)
        else {
            return nil
        }

        return [
            kCFNetworkProxiesHTTPEnable as String: true,
            kCFNetworkProxiesHTTPProxy as String: httpHost,
            kCFNetworkProxiesHTTPPort as String: httpPort,
            kCFNetworkProxiesHTTPSEnable as String: true,
            kCFNetworkProxiesHTTPSProxy as String: httpsHost,
            kCFNetworkProxiesHTTPSPort as String: httpsPort
        ]
    }

    private func proxyURL(scheme: String, host: String, port: String) -> String? {
        guard
            let normalizedHost = Self.normalizedHost(host),
            let normalizedPort = Self.normalizedPort(port)
        else {
            return nil
        }

        return "\(scheme)://\(normalizedHost):\(normalizedPort)"
    }

    private static func normalizedHost(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedPort(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmed), (1...65535).contains(port) else {
            return nil
        }

        return port
    }
}
