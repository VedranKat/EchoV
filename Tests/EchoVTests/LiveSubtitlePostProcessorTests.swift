import XCTest
@testable import EchoV

final class LiveSubtitlePostProcessorTests: XCTestCase {
    func testCleanPromptAsksForSubtitleOnlyOutput() {
        let prompt = LiveSubtitlePrompt(
            text: "um this is a subtitle",
            mode: .cleanedCaptions,
            targetLanguage: "English"
        )

        XCTAssertTrue(prompt.chatPrompt.system.contains("Return only the cleaned subtitle text."))
        XCTAssertTrue(prompt.chatPrompt.user.contains("um this is a subtitle"))
    }

    func testTranslationPromptIncludesTargetLanguage() {
        let prompt = LiveSubtitlePrompt(
            text: "good morning everyone",
            mode: .translatedSubtitles,
            targetLanguage: "Croatian"
        )

        XCTAssertTrue(prompt.chatPrompt.system.contains("Translate into Croatian."))
        XCTAssertTrue(prompt.chatPrompt.user.contains("good morning everyone"))
    }

    func testSanitizerRemovesCommonModelPrefixesAndQuotes() {
        XCTAssertEqual(
            LiveSubtitlePostProcessor.sanitizedSubtitle("Translation: \"Dobar dan svima.\""),
            "Dobar dan svima."
        )
        XCTAssertEqual(
            LiveSubtitlePostProcessor.sanitizedSubtitle("Caption:   Hello     there."),
            "Hello there."
        )
    }
}
