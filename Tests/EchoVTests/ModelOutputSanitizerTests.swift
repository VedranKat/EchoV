import XCTest
@testable import EchoV

final class ModelOutputSanitizerTests: XCTestCase {
    func testFinalAnswerStripsCompletedThinkBlocks() {
        let output = """
        <think>
        Work through hidden reasoning.
        </think>

        Final answer.
        """

        XCTAssertEqual(ModelOutputSanitizer.finalAnswer(from: output), "Final answer.")
    }

    func testFinalAnswerStripsUnclosedThinkBlocks() {
        let output = """
        Visible answer.

        <think>
        Unfinished hidden reasoning.
        """

        XCTAssertEqual(ModelOutputSanitizer.finalAnswer(from: output), "Visible answer.")
    }

    func testPartsSeparateReasoningFromContent() {
        let output = "Intro <think>hidden</think> final"

        XCTAssertEqual(
            ModelOutputSanitizer.parts(from: output),
            ModelOutputParts(content: "Intro  final", reasoning: "hidden")
        )
    }

    func testStreamParserSeparatesSplitThinkTags() {
        var parser = ModelOutputStreamParser()

        XCTAssertEqual(parser.consume("Intro <thi"), ModelOutputDelta(contentDelta: "Intro ", reasoningDelta: ""))
        XCTAssertEqual(parser.consume("nk>hidden"), ModelOutputDelta(contentDelta: "", reasoningDelta: "hidden"))
        XCTAssertEqual(parser.consume("</thi"), ModelOutputDelta(contentDelta: "", reasoningDelta: ""))
        XCTAssertEqual(parser.consume("nk> final"), ModelOutputDelta(contentDelta: " final", reasoningDelta: ""))
        XCTAssertEqual(parser.finish(), ModelOutputDelta(contentDelta: "", reasoningDelta: ""))
    }

    func testStreamParserEmitsLiteralThinkLikeTextWhenItIsNotATag() {
        var parser = ModelOutputStreamParser()

        XCTAssertEqual(parser.consume("Use <think"), ModelOutputDelta(contentDelta: "Use ", reasoningDelta: ""))
        XCTAssertEqual(parser.consume("piece literally"), ModelOutputDelta(contentDelta: "<thinkpiece literally", reasoningDelta: ""))
    }
}
