import Foundation
import Observation

@MainActor
@Observable
final class ModelStore {
    private let validator: any ModelValidator
    private let installer: ParakeetModelInstaller
    private let userDefaults: UserDefaults
    private let bookmarkKey = "selectedASRModelBookmark"

    var selectedASRModel: ASRModelSelection?
    var validation: ModelValidationResult = .notSelected
    var installState: ModelInstallState = .idle

    init(
        validator: any ModelValidator = ParakeetModelValidator(),
        installer: ParakeetModelInstaller = ParakeetModelInstaller(),
        userDefaults: UserDefaults = .standard
    ) {
        self.validator = validator
        self.installer = installer
        self.userDefaults = userDefaults
    }

    func restoreSelection() async {
        guard let bookmarkData = userDefaults.data(forKey: bookmarkKey) else {
            selectedASRModel = nil
            validation = .notSelected
            await refreshManagedInstallState()
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

        await refreshManagedInstallState()
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

    func installManagedASRModel() async {
        guard !installState.isInstalling else {
            return
        }

        installState = .installing("Starting model download...")

        do {
            let url = try await installer.install { [weak self] detail in
                Task { @MainActor in
                    self?.installState = .installing(detail)
                }
            }
            installState = .installed
            await selectASRModel(at: url)
        } catch {
            let message = "Model install failed: \(error.localizedDescription)"
            DiagnosticLog.write(message)
            installState = .failed(message)
        }
    }

    func refreshManagedInstallState() async {
        let managedURL = ParakeetLocalModelLayout.managedModelURL
        let result = await validator.validateASRModel(at: managedURL)
        installState = result.isValid ? .installed : .idle
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
