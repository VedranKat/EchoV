import XCTest
@testable import EchoV

final class PrimeDiagnosticsTests: XCTestCase {
    func testDiagnosticsGateIsCompileTimeDisabledUnlessDevFlagIsSet() {
        let defaults = isolatedUserDefaults()
        defaults.set(true, forKey: PrimeDiagnostics.defaultsKey)

        #if ECHOV_DEV_DIAGNOSTICS
        XCTAssertTrue(PrimeDiagnostics.isEnabled(userDefaults: defaults))
        #else
        XCTAssertFalse(PrimeDiagnostics.isEnabled(userDefaults: defaults))
        #endif
    }

    func testCleanupMetricsLineContainsOnlyCountsAndTimings() {
        let line = PrimeDiagnostics.cleanupCompletedLine(
            requestID: 3,
            engine: "Gemma 4 \"E4B\"\nIT",
            inputChars: "this transcript text must not be logged".count,
            promptChars: 1400,
            maxTokens: 512,
            outputChars: "cleaned private text".count,
            duration: 1.234
        )

        XCTAssertTrue(line.contains("PrimeDiagnostics cleanup completed"))
        XCTAssertTrue(line.contains("engine=\"Gemma 4 \\\"E4B\\\" IT\""))
        XCTAssertTrue(line.contains("inputChars=39"))
        XCTAssertTrue(line.contains("outputChars=20"))
        XCTAssertTrue(line.contains("durationMs=1234"))
        XCTAssertFalse(line.contains("this transcript text must not be logged"))
        XCTAssertFalse(line.contains("cleaned private text"))
        XCTAssertFalse(line.contains("\n"))
    }

    func testLlamaMetricsLineContainsOnlyMetadata() {
        let line = PrimeDiagnostics.llamaCompletedLine(
            requestID: 5,
            model: "gemma-4-E4B-it-Q4_K_M.gguf",
            pid: 18117,
            serverAge: 42.5,
            serverRequestCount: 7,
            promptChars: 1600,
            maxTokens: 1536,
            outputChars: "private model output".count,
            firstDuration: 7.1,
            retryDuration: 4.2,
            totalDuration: 11.3,
            emptyResponseDetail: "choices=1 contentChars=0 reasoningChars=2177 finishReasons=length"
        )

        XCTAssertTrue(line.contains("PrimeDiagnostics llama completed"))
        XCTAssertTrue(line.contains("pid=18117"))
        XCTAssertTrue(line.contains("serverAgeMs=42500"))
        XCTAssertTrue(line.contains("serverRequestCount=7"))
        XCTAssertTrue(line.contains("promptChars=1600"))
        XCTAssertTrue(line.contains("retryCount=1"))
        XCTAssertTrue(line.contains("retryDurationMs=4200"))
        XCTAssertTrue(line.contains("emptyResponse=\"choices=1 contentChars=0 reasoningChars=2177 finishReasons=length\""))
        XCTAssertFalse(line.contains("private model output"))
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "EchoVTests.PrimeDiagnostics.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
