import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var state: DictationState = .idle
    var lastError: AppError?
    var lastDetail: String?
    var onStatusChanged: (() -> Void)?

    func notifyStatusChanged() {
        onStatusChanged?()
    }
}
