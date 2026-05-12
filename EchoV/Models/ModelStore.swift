import Foundation
import Observation

@MainActor
@Observable
final class ModelStore {
    private let validator: any ModelValidator
    private let installer: ParakeetModelInstaller
    private let llamaRuntimeInstaller: LlamaRuntimeInstaller
    private let postProcessingInstaller: Gemma4PostProcessingModelInstaller
    private let proxySettings: @MainActor () -> ProxySettings
    private let userDefaults: UserDefaults
    private let asrBookmarkKey = "selectedASRModelBookmark"
    private let llamaRuntimeBookmarkKey = "selectedLlamaRuntimeBookmark"
    private let postProcessingBookmarkKey = "selectedPostProcessingModelBookmark"

    var selectedASRModel: ASRModelSelection?
    var validation: ModelValidationResult = .notSelected
    var installState: ModelInstallState = .idle
    var selectedLlamaRuntime: LlamaRuntimeSelection?
    var llamaRuntimeValidation: ModelValidationResult = .notSelected
    var llamaRuntimeInstallState: ModelInstallState = .idle
    var selectedPostProcessingModel: PostProcessingModelSelection?
    var postProcessingValidation: ModelValidationResult = .notSelected
    var postProcessingInstallState: ModelInstallState = .idle

    init(
        validator: any ModelValidator = ParakeetModelValidator(),
        installer: ParakeetModelInstaller = ParakeetModelInstaller(),
        llamaRuntimeInstaller: LlamaRuntimeInstaller = LlamaRuntimeInstaller(),
        postProcessingInstaller: Gemma4PostProcessingModelInstaller = Gemma4PostProcessingModelInstaller(),
        proxySettings: @escaping @MainActor () -> ProxySettings = { .disabled },
        userDefaults: UserDefaults = .standard
    ) {
        self.validator = validator
        self.installer = installer
        self.llamaRuntimeInstaller = llamaRuntimeInstaller
        self.postProcessingInstaller = postProcessingInstaller
        self.proxySettings = proxySettings
        self.userDefaults = userDefaults
    }

    func restoreSelection() async {
        await restoreASRSelection()
        await restoreLlamaRuntimeSelection()
        await restorePostProcessingSelection()
        await refreshManagedInstallState()
    }

    func selectASRModel(at url: URL) async {
        do {
            try persistBookmark(for: url, key: asrBookmarkKey)
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

    func selectLlamaRuntime(at url: URL) async {
        do {
            try persistBookmark(for: url, key: llamaRuntimeBookmarkKey)
        } catch {
            selectedLlamaRuntime = nil
            llamaRuntimeValidation = ModelValidationResult(
                isValid: false,
                message: "Could not save access to selected runtime folder."
            )
            return
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let result = await validator.validateLlamaRuntime(at: url)
        llamaRuntimeValidation = result
        selectedLlamaRuntime = LlamaRuntimeSelection(
            url: url,
            displayName: url.lastPathComponent,
            selectedAt: Date(),
            validation: result
        )
    }

    func selectPostProcessingModel(at url: URL) async {
        do {
            try persistBookmark(for: url, key: postProcessingBookmarkKey)
        } catch {
            selectedPostProcessingModel = nil
            postProcessingValidation = ModelValidationResult(
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

        let result = await validator.validatePostProcessingModel(at: url)
        postProcessingValidation = result
        selectedPostProcessingModel = PostProcessingModelSelection(
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
            let proxySettings = proxySettings()
            guard proxySettings.isValid else {
                installState = .failed(Self.invalidProxyMessage(prefix: "Model install failed"))
                return
            }

            let url = try await installer.install(proxySettings: proxySettings) { [weak self] detail in
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

    func installManagedLlamaRuntime() async {
        guard !llamaRuntimeInstallState.isInstalling else {
            return
        }

        llamaRuntimeInstallState = .installing("Starting llama.cpp runtime download...")

        do {
            let proxySettings = proxySettings()
            guard proxySettings.isValid else {
                llamaRuntimeInstallState = .failed(Self.invalidProxyMessage(prefix: "llama.cpp runtime install failed"))
                return
            }

            let url = try await llamaRuntimeInstaller.install(proxySettings: proxySettings) { [weak self] detail in
                Task { @MainActor in
                    self?.llamaRuntimeInstallState = .installing(detail)
                }
            }
            llamaRuntimeInstallState = .installed
            await selectLlamaRuntime(at: url)
        } catch {
            let message = "llama.cpp runtime install failed: \(error.localizedDescription)"
            DiagnosticLog.write(message)
            llamaRuntimeInstallState = .failed(message)
        }
    }

    func installManagedPostProcessingModel() async {
        guard !postProcessingInstallState.isInstalling else {
            return
        }

        postProcessingInstallState = .installing("Starting Gemma download...")

        do {
            let proxySettings = proxySettings()
            guard proxySettings.isValid else {
                postProcessingInstallState = .failed(Self.invalidProxyMessage(prefix: "Gemma install failed"))
                return
            }

            let url = try await postProcessingInstaller.install(proxySettings: proxySettings) { [weak self] detail in
                Task { @MainActor in
                    self?.postProcessingInstallState = .installing(detail)
                }
            }
            postProcessingInstallState = .installed
            await selectPostProcessingModel(at: url)
        } catch {
            let message = "Gemma install failed: \(error.localizedDescription)"
            DiagnosticLog.write(message)
            postProcessingInstallState = .failed(message)
        }
    }

    func refreshManagedInstallState() async {
        let managedURL = ParakeetLocalModelLayout.managedModelURL
        let result = await validator.validateASRModel(at: managedURL)
        installState = result.isValid ? .installed : .idle

        let llamaRuntimeURL = LlamaRuntimeLayout.managedRuntimeURL
        let llamaRuntimeResult = await validator.validateLlamaRuntime(at: llamaRuntimeURL)
        llamaRuntimeInstallState = llamaRuntimeResult.isValid ? .installed : .idle

        let postProcessingURL = Gemma4PostProcessingModelLayout.managedModelURL
        let postProcessingResult = await validator.validatePostProcessingModel(at: postProcessingURL)
        postProcessingInstallState = postProcessingResult.isValid ? .installed : .idle
    }

    func clearASRSelection() {
        userDefaults.removeObject(forKey: asrBookmarkKey)
        selectedASRModel = nil
        validation = .notSelected
    }

    func clearLlamaRuntimeSelection() {
        userDefaults.removeObject(forKey: llamaRuntimeBookmarkKey)
        selectedLlamaRuntime = nil
        llamaRuntimeValidation = .notSelected
    }

    func clearPostProcessingSelection() {
        userDefaults.removeObject(forKey: postProcessingBookmarkKey)
        selectedPostProcessingModel = nil
        postProcessingValidation = .notSelected
    }

    private static func invalidProxyMessage(prefix: String) -> String {
        "\(prefix): Proxy settings are incomplete. Enter host names and ports from 1 to 65535."
    }

    private func restoreASRSelection() async {
        guard let bookmarkData = userDefaults.data(forKey: asrBookmarkKey) else {
            selectedASRModel = nil
            validation = .notSelected
            return
        }

        do {
            let url = try restoreBookmarkedURL(from: bookmarkData, key: asrBookmarkKey)
            await selectASRModel(at: url)
        } catch {
            selectedASRModel = nil
            validation = ModelValidationResult(
                isValid: false,
                message: "Saved model bookmark could not be restored."
            )
        }
    }

    private func restoreLlamaRuntimeSelection() async {
        guard let bookmarkData = userDefaults.data(forKey: llamaRuntimeBookmarkKey) else {
            let managedURL = LlamaRuntimeLayout.managedRuntimeURL
            let result = await validator.validateLlamaRuntime(at: managedURL)
            if result.isValid {
                selectedLlamaRuntime = LlamaRuntimeSelection(
                    url: managedURL,
                    displayName: LlamaRuntimeLayout.displayName,
                    selectedAt: Date(),
                    validation: result
                )
                llamaRuntimeValidation = result
            } else {
                selectedLlamaRuntime = nil
                llamaRuntimeValidation = .notSelected
            }
            return
        }

        do {
            let url = try restoreBookmarkedURL(from: bookmarkData, key: llamaRuntimeBookmarkKey)
            await selectLlamaRuntime(at: url)
        } catch {
            selectedLlamaRuntime = nil
            llamaRuntimeValidation = ModelValidationResult(
                isValid: false,
                message: "Saved llama.cpp runtime bookmark could not be restored."
            )
        }
    }

    private func restorePostProcessingSelection() async {
        guard let bookmarkData = userDefaults.data(forKey: postProcessingBookmarkKey) else {
            selectedPostProcessingModel = nil
            postProcessingValidation = .notSelected
            return
        }

        do {
            let url = try restoreBookmarkedURL(from: bookmarkData, key: postProcessingBookmarkKey)
            await selectPostProcessingModel(at: url)
        } catch {
            selectedPostProcessingModel = nil
            postProcessingValidation = ModelValidationResult(
                isValid: false,
                message: "Saved post-processing model bookmark could not be restored."
            )
        }
    }

    private func restoreBookmarkedURL(from bookmarkData: Data, key: String) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            try persistBookmark(for: url, key: key)
        }

        return url
    }

    private func persistBookmark(for url: URL, key: String) throws {
        let bookmarkData = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        userDefaults.set(bookmarkData, forKey: key)
    }
}
