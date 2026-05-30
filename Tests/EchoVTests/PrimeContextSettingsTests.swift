import XCTest
@testable import EchoV

@MainActor
final class PrimeContextSettingsTests: XCTestCase {
    func testPrimeContextSettingsDefaultToEnabledWithEmptyVocabulary() {
        let settings = AppSettings(userDefaults: isolatedUserDefaults())

        XCTAssertTrue(settings.isPrimeAppAwareFormattingEnabled)
        XCTAssertTrue(settings.isPrimeCustomVocabularyEnabled)
        XCTAssertTrue(settings.primeVocabularyEntries.isEmpty)
    }

    func testPrimeVocabularyPersistsThroughUserDefaults() {
        let defaults = isolatedUserDefaults()
        let settings = AppSettings(userDefaults: defaults)
        settings.primeVocabularyEntries = [
            PrimeVocabularyEntry(term: "EchoV", aliases: ["echo vee"])
        ]

        let reloadedSettings = AppSettings(userDefaults: defaults)

        XCTAssertEqual(reloadedSettings.primeVocabularyEntries.count, 1)
        XCTAssertEqual(reloadedSettings.primeVocabularyEntries.first?.term, "EchoV")
        XCTAssertEqual(reloadedSettings.primeVocabularyEntries.first?.aliases, ["echo vee"])
    }

    func testPrimeVocabularyLoadsAtMostFiftyEntries() throws {
        let defaults = isolatedUserDefaults()
        let entries = (0..<55).map { index in
            PrimeVocabularyEntry(term: "Term \(index)")
        }
        let data = try JSONEncoder().encode(entries)
        defaults.set(data, forKey: "settings.primeVocabularyEntries")

        let settings = AppSettings(userDefaults: defaults)

        XCTAssertEqual(settings.primeVocabularyEntries.count, PrimeVocabularyEntry.maximumEntries)
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "EchoVTests.PrimeContextSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
