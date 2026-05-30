import Foundation

struct CleanupContext: Equatable, Sendable {
    let targetApplication: TargetAppContext?
    let appFormattingProfile: AppFormattingProfile?
    let vocabularyEntries: [PrimeVocabularyEntry]

    init(
        targetApplication: TargetAppContext? = nil,
        appFormattingProfile: AppFormattingProfile? = nil,
        vocabularyEntries: [PrimeVocabularyEntry] = []
    ) {
        self.targetApplication = targetApplication
        self.appFormattingProfile = appFormattingProfile
        self.vocabularyEntries = PrimeVocabularyEntry.normalizedEntries(vocabularyEntries).filter(\.isEnabled)
    }

    static let empty = CleanupContext()
}
