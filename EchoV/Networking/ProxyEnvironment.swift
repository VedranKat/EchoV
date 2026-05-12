import Darwin
import Foundation

enum ProxyEnvironment {
    private static let keys = [
        "http_proxy",
        "HTTP_PROXY",
        "https_proxy",
        "HTTPS_PROXY"
    ]
    private static let originalValues: [String: String] = keys.reduce(into: [:]) { values, key in
        if let value = getenv(key) {
            values[key] = String(cString: value)
        }
    }

    static func apply(_ settings: ProxySettings) {
        guard settings.isEnabled, settings.isValid else {
            restoreOriginalValues()
            return
        }

        for (key, value) in settings.environmentValues {
            setenv(key, value, 1)
        }
    }

    private static func restoreOriginalValues() {
        for key in keys {
            if let value = originalValues[key] {
                setenv(key, value, 1)
            } else {
                unsetenv(key)
            }
        }
    }
}
