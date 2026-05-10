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
        guard ParakeetLocalModelLayout.isDirectory(url) else {
            return ModelValidationResult(isValid: false, message: "Selected path is not a folder.")
        }

        guard let modelURL = ParakeetLocalModelLayout.modelFolderCandidate(for: url) else {
            if let closestModelURL = ParakeetLocalModelLayout.existingModelFolderCandidates(for: url).first {
                let missing = ParakeetLocalModelLayout.missingFiles(at: closestModelURL)
                return ModelValidationResult(isValid: false, message: "Missing: \(missing.joined(separator: ", "))")
            }

            return ModelValidationResult(
                isValid: false,
                message: "Select \(ParakeetLocalModelLayout.expectedFolderName), or its parent folder."
            )
        }

        let missing = ParakeetLocalModelLayout.missingFiles(at: modelURL)
        guard missing.isEmpty else {
            return ModelValidationResult(isValid: false, message: "Missing: \(missing.joined(separator: ", "))")
        }

        if modelURL.lastPathComponent == ParakeetLocalModelLayout.expectedFolderName {
            return ModelValidationResult(isValid: true, message: "Local Parakeet model is ready.")
        } else {
            return ModelValidationResult(
                isValid: true,
                message: "Local Parakeet model is ready; EchoV will use a local folder-name link for FluidAudio."
            )
        }
    }
}
