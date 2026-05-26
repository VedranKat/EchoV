import AVFoundation
import Foundation

struct AudioWindow: Sendable {
    let fileURL: URL
    let startTime: TimeInterval
    let duration: TimeInterval
}

struct AudioWindowExtractor: Sendable {
    private let temporaryDirectory: URL

    init(
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.temporaryDirectory = temporaryDirectory
    }

    func extractLeadingWindow(
        from audioURL: URL,
        duration: TimeInterval = 2.5
    ) throws -> [AudioWindow] {
        let audioFile = try AVAudioFile(forReading: audioURL)
        let sampleRate = audioFile.processingFormat.sampleRate
        let totalDuration = TimeInterval(audioFile.length) / sampleRate
        let windowDuration = min(duration, totalDuration)

        guard windowDuration > 0 else {
            return []
        }

        return try extractWindows(
            from: audioFile,
            ranges: [AudioWindowRange(startTime: 0, duration: windowDuration)]
        )
    }

    func extractOverlappingWindows(
        from audioURL: URL,
        windowDuration: TimeInterval = 2.5,
        hopDuration: TimeInterval = 1.25,
        minimumWindowDuration: TimeInterval = 1.25
    ) throws -> [AudioWindow] {
        let audioFile = try AVAudioFile(forReading: audioURL)
        let sampleRate = audioFile.processingFormat.sampleRate
        let totalDuration = TimeInterval(audioFile.length) / sampleRate

        guard totalDuration > 0 else {
            return []
        }

        if totalDuration <= windowDuration {
            return try extractWindows(
                from: audioFile,
                ranges: [AudioWindowRange(startTime: 0, duration: totalDuration)]
            )
        }

        var ranges: [AudioWindowRange] = []
        var startTime: TimeInterval = 0
        while startTime < totalDuration {
            let remainingDuration = totalDuration - startTime
            guard remainingDuration >= minimumWindowDuration else {
                break
            }

            ranges.append(AudioWindowRange(
                startTime: startTime,
                duration: min(windowDuration, remainingDuration)
            ))

            startTime += hopDuration
        }

        return try extractWindows(from: audioFile, ranges: ranges)
    }

    private func extractWindows(
        from audioFile: AVAudioFile,
        ranges: [AudioWindowRange]
    ) throws -> [AudioWindow] {
        let format = audioFile.processingFormat
        let sampleRate = format.sampleRate

        return try ranges.compactMap { range in
            let startFrame = AVAudioFramePosition((range.startTime * sampleRate).rounded(.down))
            let requestedFrameCount = AVAudioFramePosition((range.duration * sampleRate).rounded(.down))
            let endFrame = min(audioFile.length, startFrame + requestedFrameCount)
            let frameCount = endFrame - startFrame

            guard frameCount > 0, frameCount <= AVAudioFramePosition(UInt32.max) else {
                return nil
            }

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(frameCount)
            ) else {
                throw AppError.recordingFailed(details: "Could not create a voice verification audio window.")
            }

            audioFile.framePosition = startFrame
            try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(frameCount))

            let fileURL = temporaryDirectory
                .appendingPathComponent("EchoV-VoiceCheck-\(UUID().uuidString)")
                .appendingPathExtension("wav")
            let outputFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            try outputFile.write(from: buffer)

            return AudioWindow(
                fileURL: fileURL,
                startTime: range.startTime,
                duration: TimeInterval(buffer.frameLength) / sampleRate
            )
        }
    }
}

private struct AudioWindowRange {
    let startTime: TimeInterval
    let duration: TimeInterval
}
