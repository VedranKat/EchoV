import Foundation

struct ModelOutputParts: Equatable, Sendable {
    var content: String
    var reasoning: String
}

struct ModelOutputDelta: Equatable, Sendable {
    var contentDelta: String
    var reasoningDelta: String

    var isEmpty: Bool {
        contentDelta.isEmpty && reasoningDelta.isEmpty
    }
}

struct ModelOutputStreamParser: Sendable {
    private var rawOutput = ""
    private var emittedContent = ""
    private var emittedReasoning = ""

    mutating func consume(_ delta: String) -> ModelOutputDelta {
        rawOutput += delta
        let parts = ModelOutputSanitizer.parts(from: rawOutput, isFinal: false)
        let contentDelta = Self.delta(from: emittedContent, to: parts.content)
        let reasoningDelta = Self.delta(from: emittedReasoning, to: parts.reasoning)
        emittedContent = parts.content
        emittedReasoning = parts.reasoning
        return ModelOutputDelta(contentDelta: contentDelta, reasoningDelta: reasoningDelta)
    }

    mutating func finish() -> ModelOutputDelta {
        let parts = ModelOutputSanitizer.parts(from: rawOutput, isFinal: true)
        let contentDelta = Self.delta(from: emittedContent, to: parts.content)
        let reasoningDelta = Self.delta(from: emittedReasoning, to: parts.reasoning)
        emittedContent = parts.content
        emittedReasoning = parts.reasoning
        return ModelOutputDelta(contentDelta: contentDelta, reasoningDelta: reasoningDelta)
    }

    private static func delta(from previous: String, to current: String) -> String {
        guard current.hasPrefix(previous) else {
            return current
        }

        return String(current.dropFirst(previous.count))
    }
}

enum ModelOutputSanitizer {
    static func finalAnswer(from output: String) -> String {
        parts(from: output, isFinal: true).content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parts(from output: String, isFinal: Bool = true) -> ModelOutputParts {
        var content = ""
        var reasoning = ""
        var index = output.startIndex
        var isInsideReasoning = false

        while index < output.endIndex {
            if isInsideReasoning {
                if let closeTagEnd = closingThinkTagEnd(in: output, at: index) {
                    isInsideReasoning = false
                    index = closeTagEnd
                    continue
                }

                if !isFinal, isPotentialClosingThinkTag(in: output, at: index) {
                    break
                }

                reasoning.append(output[index])
                index = output.index(after: index)
            } else {
                if let openTagEnd = openingThinkTagEnd(in: output, at: index) {
                    isInsideReasoning = true
                    index = openTagEnd
                    continue
                }

                if let closeTagEnd = closingThinkTagEnd(in: output, at: index) {
                    index = closeTagEnd
                    continue
                }

                if !isFinal, isPotentialThinkTag(in: output, at: index) {
                    break
                }

                content.append(output[index])
                index = output.index(after: index)
            }
        }

        return ModelOutputParts(content: content, reasoning: reasoning)
    }

    private static func openingThinkTagEnd(in output: String, at index: String.Index) -> String.Index? {
        let lowercased = output[index...].lowercased()
        guard lowercased.hasPrefix("<think") else {
            return nil
        }

        let boundaryIndex = output.index(index, offsetBy: 6)
        guard boundaryIndex < output.endIndex else {
            return nil
        }

        let boundary = output[boundaryIndex]
        guard boundary == ">" || boundary.isWhitespace else {
            return nil
        }

        guard let closeIndex = output[index...].firstIndex(of: ">") else {
            return nil
        }

        return output.index(after: closeIndex)
    }

    private static func closingThinkTagEnd(in output: String, at index: String.Index) -> String.Index? {
        let lowercased = output[index...].lowercased()
        guard lowercased.hasPrefix("</think>") else {
            return nil
        }

        return output.index(index, offsetBy: 8)
    }

    private static func isPotentialThinkTag(in output: String, at index: String.Index) -> Bool {
        isPotentialOpeningThinkTag(in: output, at: index)
            || isPotentialClosingThinkTag(in: output, at: index)
    }

    private static func isPotentialOpeningThinkTag(in output: String, at index: String.Index) -> Bool {
        let remaining = output[index...].lowercased()
        guard remaining.hasPrefix("<") else {
            return false
        }

        if "<think".hasPrefix(remaining) {
            return true
        }

        guard remaining.hasPrefix("<think") else {
            return false
        }

        let boundaryIndex = output.index(index, offsetBy: 6)
        guard boundaryIndex < output.endIndex else {
            return true
        }

        let boundary = output[boundaryIndex]
        return boundary == ">" || boundary.isWhitespace
    }

    private static func isPotentialClosingThinkTag(in output: String, at index: String.Index) -> Bool {
        let remaining = output[index...].lowercased()
        return remaining.hasPrefix("<") && "</think>".hasPrefix(remaining)
    }
}
