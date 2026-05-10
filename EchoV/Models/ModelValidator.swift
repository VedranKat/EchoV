import Foundation

protocol ModelValidator: Sendable {
    func validateASRModel(at url: URL) async -> ModelValidationResult
}

struct ModelValidationResult: Equatable, Sendable {
    let isValid: Bool
    let message: String

    static let notSelected = ModelValidationResult(
        isValid: false,
        message: "No model selected."
    )
}

struct ParakeetModelValidator: ModelValidator {
    func validateASRModel(at url: URL) async -> ModelValidationResult {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return ModelValidationResult(isValid: false, message: "Selected path is not a folder.")
        }

        let requiredNames = ["parakeet_vocab.json"]

        let missing = requiredNames.filter { name in
            !FileManager.default.fileExists(atPath: url.appendingPathComponent(name).path)
        }

        guard missing.isEmpty else {
            return ModelValidationResult(isValid: false, message: "Missing: \(missing.joined(separator: ", "))")
        }

        let hasCoreMLAsset = hasFile(withExtension: "mlmodelc", under: url)
            || hasFile(withExtension: "mlpackage", under: url)
            || hasFile(withExtension: "mlmodel", under: url)

        guard hasCoreMLAsset else {
            return ModelValidationResult(
                isValid: false,
                message: "No Core ML model asset found."
            )
        }

        return ModelValidationResult(isValid: true, message: "Model folder looks usable.")
    }

    private func hasFile(withExtension fileExtension: String, under url: URL) -> Bool {
        guard
            let enumerator = FileManager.default.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return false
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == fileExtension {
                return true
            }
        }

        return false
    }
}
