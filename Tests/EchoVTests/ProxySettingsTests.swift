import XCTest
@testable import EchoV

final class ProxySettingsTests: XCTestCase {
    func testDisabledProxyIsValidWithoutHosts() {
        let settings = ProxySettings.disabled

        XCTAssertTrue(settings.isValid)
        XCTAssertNil(settings.connectionProxyDictionary)
        XCTAssertTrue(settings.environmentValues.isEmpty)
    }

    func testBuildsProxyDictionaryAndEnvironmentValues() throws {
        let settings = ProxySettings(
            isEnabled: true,
            httpHost: "proxy.example.com",
            httpPort: "8080",
            httpsHost: "",
            httpsPort: "",
            usesSameProxyForHTTPS: true
        )

        let dictionary = try XCTUnwrap(settings.connectionProxyDictionary)
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPProxy as String] as? String, "proxy.example.com")
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPPort as String] as? Int, 8080)
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPSProxy as String] as? String, "proxy.example.com")
        XCTAssertEqual(dictionary[kCFNetworkProxiesHTTPSPort as String] as? Int, 8080)
        XCTAssertEqual(settings.environmentValues["http_proxy"], "http://proxy.example.com:8080")
        XCTAssertEqual(settings.environmentValues["https_proxy"], "http://proxy.example.com:8080")
    }

    func testRejectsInvalidPort() {
        let settings = ProxySettings(
            isEnabled: true,
            httpHost: "proxy.example.com",
            httpPort: "70000",
            httpsHost: "",
            httpsPort: "",
            usesSameProxyForHTTPS: true
        )

        XCTAssertFalse(settings.isValid)
        XCTAssertNil(settings.connectionProxyDictionary)
    }
}
