import CoreML
import Foundation

enum ASRComputeMode: String, CaseIterable, Identifiable, Sendable {
    case all
    case cpuAndGPU
    case cpuAndNeuralEngine
    case cpuOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            "All"
        case .cpuAndGPU:
            "CPU + GPU"
        case .cpuAndNeuralEngine:
            "CPU + Neural Engine"
        case .cpuOnly:
            "CPU Only"
        }
    }

    var computeUnits: MLComputeUnits {
        switch self {
        case .all:
            .all
        case .cpuAndGPU:
            .cpuAndGPU
        case .cpuAndNeuralEngine:
            .cpuAndNeuralEngine
        case .cpuOnly:
            .cpuOnly
        }
    }
}
