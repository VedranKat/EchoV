import Foundation
import XCTest
@testable import EchoV

@MainActor
final class ModelStorePostProcessingModelTests: XCTestCase {
    func testDefaultsPostProcessingModelDefinitionToE2B() async {
        let defaults = isolatedUserDefaults()
        let store = ModelStore(
            validator: PostProcessingDefinitionValidator(installedDefinitionIDs: []),
            userDefaults: defaults
        )

        await store.restoreSelection()

        XCTAssertEqual(store.selectedPostProcessingModelDefinition, .gemma4E2B)
    }

    func testInvalidSavedPostProcessingModelDefinitionFallsBackToE2B() async {
        let defaults = isolatedUserDefaults()
        defaults.set("missing-model", forKey: "selectedPostProcessingModelDefinition")
        let store = ModelStore(
            validator: PostProcessingDefinitionValidator(installedDefinitionIDs: []),
            userDefaults: defaults
        )

        await store.restoreSelection()

        XCTAssertEqual(store.selectedPostProcessingModelDefinition, .gemma4E2B)
        XCTAssertNil(defaults.string(forKey: "selectedPostProcessingModelDefinition"))
    }

    func testRefreshTracksManagedInstallStatePerPostProcessingModel() async {
        let store = ModelStore(
            validator: PostProcessingDefinitionValidator(
                installedDefinitionIDs: [PostProcessingModelDefinition.gemma4E4B.id]
            ),
            userDefaults: isolatedUserDefaults()
        )

        await store.restoreSelection()

        XCTAssertEqual(store.postProcessingInstallState(for: .gemma4E2B), .idle)
        XCTAssertEqual(store.postProcessingInstallState(for: .gemma4E4B), .installed)
    }

    func testDeleteIsEnabledOnlyForInstalledSelectedPostProcessingModel() async {
        let store = ModelStore(
            validator: PostProcessingDefinitionValidator(
                installedDefinitionIDs: [PostProcessingModelDefinition.gemma4E4B.id]
            ),
            userDefaults: isolatedUserDefaults()
        )

        await store.restoreSelection()
        XCTAssertFalse(store.canDeleteSelectedManagedPostProcessingModel)

        await store.selectPostProcessingModelDefinition(.gemma4E4B)
        XCTAssertTrue(store.canDeleteSelectedManagedPostProcessingModel)
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "EchoVTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}

private struct PostProcessingDefinitionValidator: ModelValidator {
    let installedDefinitionIDs: Set<String>

    func validateASRModel(at url: URL) async -> ModelValidationResult {
        .notSelected
    }

    func validateLlamaRuntime(at url: URL) async -> ModelValidationResult {
        .notSelected
    }

    func validatePostProcessingModel(
        at url: URL,
        modelDefinition: PostProcessingModelDefinition
    ) async -> ModelValidationResult {
        ModelValidationResult(
            isValid: installedDefinitionIDs.contains(modelDefinition.id),
            message: "\(modelDefinition.displayName) test validation"
        )
    }

    func validateSpeakerVerifierRuntime(at url: URL) async -> ModelValidationResult {
        .notSelected
    }
}
