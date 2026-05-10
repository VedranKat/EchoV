import Foundation

enum ModelInstallState: Equatable, Sendable {
    case idle
    case installing(String)
    case installed
    case failed(String)

    var message: String {
        switch self {
        case .idle:
            "Not installed by EchoV."
        case .installing(let detail):
            detail
        case .installed:
            "Installed by EchoV."
        case .failed(let detail):
            detail
        }
    }

    var isInstalling: Bool {
        if case .installing = self {
            return true
        }
        return false
    }
}
