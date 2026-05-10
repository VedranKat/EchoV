import Foundation
import Observation

@MainActor
@Observable
final class ModelStore {
    private let validator: any ModelValidator
    private let userDefaults: UserDefaults
    private let bookmarkKey = "selectedASRModelBookmark"

    var selectedASRModel: ASRModelSelection?
    var validation: ModelValidationResult = .notSelected

    init(
        validator: any ModelValidator = ParakeetModelValidator(),
        userDefaults: UserDefaults = .standard
    ) {
        self.validator = validator
        self.userDefaults = userDefaults
    }

    func restoreSelection() async {
        guard let bookmarkData = userDefaults.data(forKey: bookmarkKey) else {
            selectedASRModel = nil
            validation = .notSelected
            return
        }

        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                try persistBookmark(for: url)
            }

            await selectASRModel(at: url)
        } catch {
            selectedASRModel = nil
            validation = ModelValidationResult(
                isValid: false,
                message: "Saved model bookmark could not be restored."
            )
        }
    }

    func selectASRModel(at url: URL) async {
        do {
            try persistBookmark(for: url)
        } catch {
            selectedASRModel = nil
            validation = ModelValidationResult(
                isValid: false,
                message: "Could not save access to selected model folder."
            )
            return
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let result = await validator.validateASRModel(at: url)
        validation = result
        selectedASRModel = ASRModelSelection(
            url: url,
            displayName: url.lastPathComponent,
            selectedAt: Date(),
            validation: result
        )
    }

    func clearSelection() {
        userDefaults.removeObject(forKey: bookmarkKey)
        selectedASRModel = nil
        validation = .notSelected
    }

    private func persistBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        userDefaults.set(bookmarkData, forKey: bookmarkKey)
    }
}
