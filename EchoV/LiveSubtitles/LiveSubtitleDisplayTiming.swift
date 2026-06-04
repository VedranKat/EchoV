import Foundation

struct LiveSubtitleDisplayUnit: Equatable, Sendable {
    let text: String
    let holdSeconds: TimeInterval
    let minimumReadableSeconds: TimeInterval
}

enum LiveSubtitleDisplayTiming {
    private static let targetWordsPerUnit = 10
    private static let maximumWordsPerUnit = 12
    private static let maximumCharactersPerUnit = 74
    private static let minimumHoldSeconds: TimeInterval = 1.15
    private static let maximumHoldSeconds: TimeInterval = 8.0
    private static let maximumTotalHoldSeconds: TimeInterval = 14.0
    private static let readableWordsPerSecond = 3.0
    private static let readableCharactersPerSecond = 18.0

    static func displayUnits(
        for text: String,
        spokenDuration: TimeInterval,
        baseHoldSeconds: TimeInterval
    ) -> [LiveSubtitleDisplayUnit] {
        let normalized = normalizedWhitespace(text)
        guard !normalized.isEmpty else {
            return []
        }

        let parts = split(normalized)
        let totalWords = max(1, parts.reduce(0) { $0 + wordCount($1) })
        let requestedFloor = clampedBaseHold(baseHoldSeconds)
        var units = parts.map { part in
            let partWords = max(1, wordCount(part))
            let spokenShare = max(0, spokenDuration) * (Double(partWords) / Double(totalWords))
            let hold = minimumReadableHoldSeconds(
                for: part,
                spokenDuration: spokenShare,
                baseHoldSeconds: requestedFloor
            )
            return LiveSubtitleDisplayUnit(
                text: part,
                holdSeconds: hold,
                minimumReadableSeconds: hold
            )
        }

        let minimumTotal = units.reduce(0) { $0 + $1.holdSeconds }
        let targetTotal = min(
            min(maximumTotalHoldSeconds, maximumHoldSeconds * Double(units.count)),
            max(minimumTotal, max(0, spokenDuration) + requestedFloor)
        )
        let extra = max(0, targetTotal - minimumTotal)
        guard extra > 0 else {
            return units
        }

        units = units.map { unit in
            let unitWords = max(1, wordCount(unit.text))
            let share = Double(unitWords) / Double(totalWords)
            return LiveSubtitleDisplayUnit(
                text: unit.text,
                holdSeconds: min(maximumHoldSeconds, unit.holdSeconds + (extra * share)),
                minimumReadableSeconds: unit.minimumReadableSeconds
            )
        }
        return units
    }

    static func holdSeconds(
        for text: String,
        spokenDuration: TimeInterval,
        baseHoldSeconds: TimeInterval
    ) -> TimeInterval {
        let requestedFloor = clampedBaseHold(baseHoldSeconds)
        return min(
            maximumHoldSeconds,
            max(
                minimumReadableHoldSeconds(
                    for: text,
                    spokenDuration: spokenDuration,
                    baseHoldSeconds: requestedFloor
                ),
                max(0, spokenDuration) + requestedFloor
            )
        )
    }

    static func normalizedWhitespace(_ text: String) -> String {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func split(_ text: String) -> [String] {
        var units: [String] = []
        for sentence in sentenceLikeParts(text) {
            units.append(contentsOf: splitLongPart(sentence))
        }
        return units.isEmpty ? [text] : units
    }

    private static func sentenceLikeParts(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""

        for character in text {
            current.append(character)
            if ".?!".contains(character), shouldFinishPart(current) {
                parts.append(normalizedWhitespace(current))
                current.removeAll(keepingCapacity: true)
            }
        }

        let tail = normalizedWhitespace(current)
        if !tail.isEmpty {
            parts.append(tail)
        }

        return parts
    }

    private static func splitLongPart(_ text: String) -> [String] {
        guard wordCount(text) > maximumWordsPerUnit || text.count > maximumCharactersPerUnit else {
            return [text]
        }

        let words = text.split(separator: " ").map(String.init)
        var units: [String] = []
        var current: [String] = []
        var currentCharacters = 0

        for word in words {
            let nextCharacters = currentCharacters + word.count + (current.isEmpty ? 0 : 1)
            let shouldBreak = !current.isEmpty
                && (current.count >= targetWordsPerUnit
                    || nextCharacters > maximumCharactersPerUnit
                    || (current.count >= 6 && word.hasClauseBoundaryPrefix))

            if shouldBreak {
                units.append(current.joined(separator: " "))
                current.removeAll(keepingCapacity: true)
                currentCharacters = 0
            }

            current.append(word)
            currentCharacters += word.count + (current.count == 1 ? 0 : 1)
        }

        if !current.isEmpty {
            units.append(current.joined(separator: " "))
        }

        return units
    }

    private static func shouldFinishPart(_ text: String) -> Bool {
        wordCount(text) >= 3 || text.count >= 24
    }

    private static func minimumReadableHoldSeconds(
        for text: String,
        spokenDuration: TimeInterval,
        baseHoldSeconds: TimeInterval
    ) -> TimeInterval {
        let normalized = normalizedWhitespace(text)
        let words = Double(max(1, wordCount(normalized)))
        let characters = Double(max(1, normalized.count))
        let readingSeconds = max(words / readableWordsPerSecond, characters / readableCharactersPerSecond)
        let spokenSeconds = max(0, spokenDuration * 0.9)
        return max(baseHoldSeconds, min(maximumHoldSeconds, max(readingSeconds, spokenSeconds)))
    }

    private static func clampedBaseHold(_ baseHoldSeconds: TimeInterval) -> TimeInterval {
        max(minimumHoldSeconds, min(baseHoldSeconds, maximumHoldSeconds))
    }

    private static func wordCount(_ text: String) -> Int {
        text.split { !$0.isLetter && !$0.isNumber }.count
    }
}

enum LiveSubtitleDisplaySyncPolicy {
    static let maximumCaptionEndLagSeconds: TimeInterval = 3.0
    static let maximumCaptionStartLagSeconds: TimeInterval = 8.5
    static let maximumAverageCaptionEndLagSeconds: TimeInterval = 1.5
    static let maximumQueuedSubtitleLagSeconds: TimeInterval = 5.5
    static let maximumQueuedDisplayUnits = 4

    private static let minimumBacklogDwellSeconds: TimeInterval = 0.75
    private static let maximumBacklogDwellSeconds: TimeInterval = 1.45
    private static let maximumReadyDwellSeconds: TimeInterval = 1.45

    static func dwellSeconds(
        for unit: LiveSubtitleDisplayUnit,
        hasBacklog: Bool,
        captionEndLagSeconds: TimeInterval
    ) -> TimeInterval {
        if captionEndLagSeconds >= maximumCaptionEndLagSeconds {
            return min(unit.holdSeconds, minimumBacklogDwellSeconds)
        }

        let readyDwell = min(
            unit.holdSeconds,
            max(minimumBacklogDwellSeconds, min(unit.minimumReadableSeconds, maximumReadyDwellSeconds))
        )

        guard hasBacklog else {
            return readyDwell
        }

        return min(readyDwell, maximumBacklogDwellSeconds)
    }
}

private extension String {
    var hasClauseBoundaryPrefix: Bool {
        let lowercasedWord = lowercased()
        return lowercasedWord.hasPrefix("and")
            || lowercasedWord.hasPrefix("but")
            || lowercasedWord.hasPrefix("or")
            || lowercasedWord.hasPrefix("so")
            || lowercasedWord.hasPrefix("because")
    }
}
