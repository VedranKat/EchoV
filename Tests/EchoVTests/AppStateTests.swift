import XCTest
@testable import EchoV

@MainActor
final class AppStateTests: XCTestCase {
    func testRejectedWakeTranscriptLogKeepsNewestTwenty() {
        let appState = AppState()

        for index in 0..<25 {
            appState.recordRejectedWakeTranscript(VoiceModeRejectedWakeTranscript(
                id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", index))")!,
                text: "rejected \(index)",
                reason: .notExactActivationCommand,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            ))
        }

        XCTAssertEqual(appState.rejectedWakeTranscripts.count, 20)
        XCTAssertEqual(appState.rejectedWakeTranscripts.first?.text, "rejected 24")
        XCTAssertEqual(appState.rejectedWakeTranscripts.last?.text, "rejected 5")
    }
}
