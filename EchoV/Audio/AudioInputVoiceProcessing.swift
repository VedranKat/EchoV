import AVFoundation

enum AudioInputVoiceProcessingResult: Equatable {
    case disabled
    case enabled(isAGCEnabled: Bool)
    case failed(String)
}

enum AudioInputVoiceProcessing {
    static func configure(
        inputNode: AVAudioInputNode,
        isEnabled: Bool
    ) -> AudioInputVoiceProcessingResult {
        guard isEnabled else {
            return .disabled
        }

        do {
            try inputNode.setVoiceProcessingEnabled(true)
            inputNode.isVoiceProcessingAGCEnabled = true
            return .enabled(isAGCEnabled: inputNode.isVoiceProcessingAGCEnabled)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
