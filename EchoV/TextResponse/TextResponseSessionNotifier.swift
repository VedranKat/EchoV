import Foundation

@MainActor
final class TextResponseSessionNotifier {
    var onSessionCreated: ((UUID, String, String) -> Void)?

    func sessionCreated(id: UUID, title: String, responseText: String) {
        onSessionCreated?(id, title, responseText)
    }
}
