import Foundation

struct ProxyURLSessionFactory: Sendable {
    let proxySettings: ProxySettings

    func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        if let proxyDictionary = proxySettings.connectionProxyDictionary {
            configuration.connectionProxyDictionary = proxyDictionary
        }

        return URLSession(configuration: configuration)
    }
}
