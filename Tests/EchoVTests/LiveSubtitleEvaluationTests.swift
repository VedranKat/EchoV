import AVFoundation
import CryptoKit
@preconcurrency import FluidAudio
import XCTest
@testable import EchoV

@MainActor
final class LiveSubtitleEvaluationTests: XCTestCase {
    func testHarnessCommand() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let command = environment["ECHOV_LIVE_SUBTITLE_EVAL_COMMAND"] else {
            throw XCTSkip("Set ECHOV_LIVE_SUBTITLE_EVAL_COMMAND or use Tools/LiveSubtitleEval/run-live-subtitle-eval.sh.")
        }

        let runner = LiveSubtitleEvaluationRunner(environment: environment)
        switch command {
        case "list":
            runner.listScenarios()
        case "dry-run":
            try runner.writeDryRun()
        case "self-test":
            try runner.runSelfTest()
        case "run":
            try await runner.runRealBaseline()
        case "verify-latest":
            try runner.verifyLatest()
        default:
            XCTFail("Unknown live subtitle eval command: \(command)")
        }
    }

    func testStackedVisibilityKeepsPreviousRowsReadable() {
        let events = [
            makeSubtitleEvent(sequence: 0, displayAt: 0.0),
            makeSubtitleEvent(sequence: 1, displayAt: 0.8),
            makeSubtitleEvent(sequence: 2, displayAt: 1.6)
        ]

        let singleRowEvents = applyVisibilityTiming(to: events, maxVisibleLines: 1)
        XCTAssertEqual(singleRowEvents[0].primaryDwellSeconds, 0.8, accuracy: 0.0001)
        XCTAssertEqual(singleRowEvents[0].totalVisibleSeconds, 0.8, accuracy: 0.0001)

        let stackedEvents = applyVisibilityTiming(to: events, maxVisibleLines: 2)
        XCTAssertEqual(stackedEvents[0].primaryDwellSeconds, 0.8, accuracy: 0.0001)
        XCTAssertEqual(stackedEvents[0].totalVisibleSeconds, 1.6, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(stackedEvents[0].totalVisibleSeconds, stackedEvents[0].minimumReadableSeconds)
    }

    private func makeSubtitleEvent(sequence: Int, displayAt: Double) -> SubtitleEvent {
        SubtitleEvent(
            sequence: sequence,
            unitIndex: 0,
            chunkStart: max(0, displayAt - 1.0),
            chunkEnd: displayAt,
            processingSeconds: 0.1,
            displayAt: displayAt,
            scheduledHoldSeconds: 2.2,
            activeDwellSeconds: 0.8,
            usedCatchUpDwell: false,
            primaryDwellSeconds: 0,
            totalVisibleSeconds: 0,
            minimumReadableSeconds: 1.4,
            captionStartLagSeconds: 0,
            captionEndLagSeconds: 0,
            wordCount: 4,
            text: "alpha beta gamma \(sequence)"
        )
    }
}

@MainActor
private final class LiveSubtitleEvaluationRunner {
    private let environment: [String: String]
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let rootURL: URL
    private let runsURL: URL
    private let fixturesURL: URL
    private let latestRunURL: URL

    init(environment: [String: String]) {
        self.environment = environment
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let packageRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        rootURL = packageRoot.appendingPathComponent(".local/live_subtitle_eval", isDirectory: true)
        runsURL = rootURL.appendingPathComponent("runs", isDirectory: true)
        fixturesURL = rootURL.appendingPathComponent("fixtures", isDirectory: true)
        latestRunURL = rootURL.appendingPathComponent("latest-run.txt")
    }

    func listScenarios() {
        for scenario in selectedScenarios(allWhenUnspecified: true) {
            print("\(scenario.id): \(scenario.title)")
        }
    }

    func writeDryRun() throws {
        let run = try makeRunDirectory(kind: "dry-run")
        let manifest = DryRunManifest(
            scenarios: selectedScenarios(allWhenUnspecified: true),
            presets: selectedPresets().map(\.rawValue),
            holdSeconds: holdSeconds,
            maxVisibleLines: maxVisibleLines,
            voiceIdentifier: voiceIdentifier
        )
        try writeJSON(manifest, to: run.url.appendingPathComponent("manifest.json"))
        try writeSummary(
            RunSummary(
                runID: run.id,
                command: "dry-run",
                createdAt: Date(),
                scenarioCount: manifest.scenarios.count,
                reportCount: 0,
                aggregate: AggregateReport.empty,
                reports: []
            ),
            to: run.url
        )
        try pruneRuns(keeping: run.id)
        print("Live subtitle dry run: \(run.url.path)")
    }

    func runSelfTest() throws {
        let run = try makeRunDirectory(kind: "self-test")
        let scenario = EvalScenario(
            id: "self_test",
            title: "Self-test",
            pieces: [
                ScriptPiece(
                    text: "alpha beta gamma delta",
                    speed: 1,
                    pauseAfter: 0.4
                )
            ]
        )
        let report = score(
            scenario: scenario,
            preset: "balanced",
            fixture: AudioFixture(
                audioPath: "self-test.wav",
                duration: 3.0,
                expectedText: scenario.expectedText,
                speechIntervals: [TimeIntervalRange(start: 0.0, end: 2.0)]
            ),
            observedText: "alpha beta gamma delta",
            events: [
                SubtitleEvent(
                    sequence: 0,
                    unitIndex: 0,
                    chunkStart: 0.0,
                    chunkEnd: 2.0,
                    processingSeconds: 0.25,
                    displayAt: 2.25,
                    scheduledHoldSeconds: 2.2,
                    activeDwellSeconds: 2.2,
                    usedCatchUpDwell: false,
                    primaryDwellSeconds: 2.2,
                    totalVisibleSeconds: 2.2,
                    minimumReadableSeconds: 1.3,
                    captionStartLagSeconds: 2.25,
                    captionEndLagSeconds: 0.25,
                    wordCount: 4,
                    text: "alpha beta gamma delta"
                )
            ],
            chunkCount: 1,
            holdSeconds: holdSeconds
        )
        XCTAssertEqual(report.wordErrorRate, 0, accuracy: 0.0001)
        XCTAssertTrue(report.passed)

        let reportURL = run.url.appendingPathComponent(report.caseID, isDirectory: true)
        try fileManager.createDirectory(at: reportURL, withIntermediateDirectories: true)
        try writeJSON(report, to: reportURL.appendingPathComponent("report.json"))

        let summary = RunSummary(
            runID: run.id,
            command: "self-test",
            createdAt: Date(),
            scenarioCount: 1,
            reportCount: 1,
            aggregate: AggregateReport(reports: [report]),
            reports: [report.relativeReportPath]
        )
        try writeSummary(summary, to: run.url)
        try writeVerification(summary: summary, to: run.url)
        try pruneRuns(keeping: run.id)
        print("Live subtitle self-test report: \(run.url.path)")
    }

    func runRealBaseline() async throws {
        try fileManager.createDirectory(at: fixturesURL, withIntermediateDirectories: true)
        let runDirectory = try makeRunDirectory(kind: "baseline")
        let scenarios = selectedScenarios(allWhenUnspecified: false)
        let presets = selectedPresets()
        let modelURL = parakeetModelURL
        guard ParakeetLocalModelLayout.containsRequiredFiles(at: modelURL) else {
            throw AppError.modelPathInvalid(details: "Missing Parakeet model files at \(modelURL.path)")
        }

        let tts = try await makeTTSManager()
        let asrEngine = FluidAudioParakeetEngine(modelURL: modelURL, computeMode: computeMode)
        asrEngine.onStatusUpdate = { status in
            print("ASR status: \(status)")
        }
        try await asrEngine.prepare()

        var reports: [ScenarioReport] = []
        for scenario in scenarios {
            print("Generating fixture: \(scenario.id)")
            let fixture = try await fixture(for: scenario, tts: tts)
            for preset in presets {
                print("Running scenario=\(scenario.id) preset=\(preset)")
                let report = try await evaluate(
                    scenario: scenario,
                    fixture: fixture,
                    preset: preset,
                    asrEngine: asrEngine
                )
                reports.append(report)

                let reportDirectory = runDirectory.url.appendingPathComponent(report.caseID, isDirectory: true)
                try fileManager.createDirectory(at: reportDirectory, withIntermediateDirectories: true)
                try writeJSON(report, to: reportDirectory.appendingPathComponent("report.json"))
                try writeJSON(report.events, to: reportDirectory.appendingPathComponent("events.json"))
            }
        }

        let summary = RunSummary(
            runID: runDirectory.id,
            command: "run",
            createdAt: Date(),
            scenarioCount: scenarios.count,
            reportCount: reports.count,
            aggregate: AggregateReport(reports: reports),
            reports: reports.map(\.relativeReportPath)
        )
        try writeSummary(summary, to: runDirectory.url)
        try writeVerification(summary: summary, to: runDirectory.url)
        try pruneRuns(keeping: runDirectory.id)
        print("Live subtitle baseline report: \(runDirectory.url.path)")
    }

    func verifyLatest() throws {
        let latestPath = try String(contentsOf: latestRunURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !latestPath.isEmpty else {
            throw EvalError("latest-run.txt is empty")
        }
        let runURL = URL(fileURLWithPath: latestPath, isDirectory: true)
        let summaryURL = runURL.appendingPathComponent("summary.json")
        let summary = try decoder.decode(RunSummary.self, from: Data(contentsOf: summaryURL))
        try writeVerification(summary: summary, to: runURL)
        print("Live subtitle verification: \(runURL.appendingPathComponent("verification.json").path)")
    }

    private func evaluate(
        scenario: EvalScenario,
        fixture: AudioFixture,
        preset: LiveSubtitleChunkPreset,
        asrEngine: FluidAudioParakeetEngine
    ) async throws -> ScenarioReport {
        let configuration = preset.defaults.configuration
        let chunks = try await chunkFixture(fixture, configuration: configuration)
        var candidates: [DisplayCandidate] = []
        var failedChunks: [FailedChunk] = []
        var transcriberAvailableAt = 0.0
        let baseDate = Self.timelineBaseDate

        for chunk in chunks {
            let chunkEnd = chunk.endedAt.timeIntervalSince(baseDate)
            let chunkStart = chunk.startedAt.timeIntervalSince(baseDate)
            guard chunk.duration >= 0.30 else {
                failedChunks.append(
                    FailedChunk(
                        sequence: chunk.sequence,
                        chunkStart: chunkStart,
                        chunkEnd: chunkEnd,
                        duration: chunk.duration,
                        reason: "too_short_for_asr"
                    )
                )
                try? fileManager.removeItem(at: chunk.fileURL)
                continue
            }

            let processingStart = Date()
            let normalizedChunkURL = try normalizeForASR(chunk.fileURL)
            let transcript: Transcript
            do {
                transcript = try await asrEngine.transcribe(audioURL: normalizedChunkURL, options: ASROptions())
            } catch {
                failedChunks.append(
                    FailedChunk(
                        sequence: chunk.sequence,
                        chunkStart: chunkStart,
                        chunkEnd: chunkEnd,
                        duration: chunk.duration,
                        reason: error.localizedDescription
                    )
                )
                try? fileManager.removeItem(at: chunk.fileURL)
                try? fileManager.removeItem(at: normalizedChunkURL)
                continue
            }
            let processingSeconds = max(0.001, Date().timeIntervalSince(processingStart))
            let text = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
            try? fileManager.removeItem(at: chunk.fileURL)
            try? fileManager.removeItem(at: normalizedChunkURL)

            guard !text.isEmpty else {
                continue
            }

            let displayAt = max(chunkEnd, transcriberAvailableAt) + processingSeconds
            transcriberAvailableAt = displayAt
            let units = LiveSubtitleDisplayTiming.displayUnits(
                for: text,
                spokenDuration: chunk.duration,
                baseHoldSeconds: holdSeconds
            )
            for (unitIndex, unit) in units.enumerated() {
                candidates.append(
                    DisplayCandidate(
                        sequence: chunk.sequence,
                        unitIndex: unitIndex,
                        chunkStart: chunkStart,
                        chunkEnd: chunkEnd,
                        processingSeconds: processingSeconds,
                        enqueueAt: displayAt,
                        unit: unit
                    )
                )
            }
        }

        let timedEvents = applyVisibilityTiming(
            to: scheduleDisplayEvents(from: candidates),
            maxVisibleLines: maxVisibleLines
        )
        return score(
            scenario: scenario,
            preset: preset.rawValue,
            fixture: fixture,
            observedText: timedEvents.map(\.text).joined(separator: " "),
            events: timedEvents,
            failedChunks: failedChunks,
            chunkCount: chunks.count,
            holdSeconds: holdSeconds
        )
    }

    private func scheduleDisplayEvents(from candidates: [DisplayCandidate]) -> [SubtitleEvent] {
        let arrivals = candidates.sorted { first, second in
            if first.enqueueAt == second.enqueueAt {
                return first.sequence == second.sequence
                    ? first.unitIndex < second.unitIndex
                    : first.sequence < second.sequence
            }
            return first.enqueueAt < second.enqueueAt
        }
        var arrivalIndex = 0
        var displayQueue: [DisplayCandidate] = []
        var latestQueuedChunkEnd = 0.0
        var currentTime = 0.0
        var events: [SubtitleEvent] = []

        func trimDisplayQueueForSync() {
            displayQueue.removeAll {
                latestQueuedChunkEnd - $0.chunkEnd > LiveSubtitleDisplaySyncPolicy.maximumQueuedSubtitleLagSeconds
            }
            while displayQueue.count > LiveSubtitleDisplaySyncPolicy.maximumQueuedDisplayUnits {
                displayQueue.removeFirst()
            }
        }

        func enqueueArrivals(upTo limit: Double) {
            while arrivalIndex < arrivals.count, arrivals[arrivalIndex].enqueueAt <= limit + 0.0001 {
                let candidate = arrivals[arrivalIndex]
                latestQueuedChunkEnd = max(latestQueuedChunkEnd, candidate.chunkEnd)
                displayQueue.append(candidate)
                arrivalIndex += 1
            }
            trimDisplayQueueForSync()
        }

        func dwellTarget(for candidate: DisplayCandidate, at time: Double) -> Double {
            LiveSubtitleDisplaySyncPolicy.dwellSeconds(
                for: candidate.unit,
                hasBacklog: displayQueue.contains { $0.chunkEnd > candidate.chunkEnd },
                captionEndLagSeconds: max(0, time - candidate.chunkEnd)
            )
        }

        while arrivalIndex < arrivals.count || !displayQueue.isEmpty {
            if displayQueue.isEmpty, arrivalIndex < arrivals.count {
                currentTime = max(currentTime, arrivals[arrivalIndex].enqueueAt)
            }
            enqueueArrivals(upTo: currentTime)

            guard !displayQueue.isEmpty else {
                continue
            }

            let candidate = displayQueue.removeFirst()
            let displayAt = max(currentTime, candidate.enqueueAt)
            currentTime = displayAt
            var target = max(0.2, dwellTarget(for: candidate, at: currentTime))
            var usedCatchUpDwell = target + 0.001 < candidate.unit.minimumReadableSeconds

            while currentTime - displayAt + 0.0001 < target {
                guard arrivalIndex < arrivals.count else {
                    currentTime = displayAt + target
                    break
                }

                let nextArrivalAt = arrivals[arrivalIndex].enqueueAt
                guard nextArrivalAt <= displayAt + target + 0.0001 else {
                    currentTime = displayAt + target
                    break
                }

                currentTime = max(currentTime, nextArrivalAt)
                enqueueArrivals(upTo: currentTime)
                target = max(0.2, dwellTarget(for: candidate, at: currentTime))
                usedCatchUpDwell = usedCatchUpDwell || target + 0.001 < candidate.unit.minimumReadableSeconds
            }

            let actualDwell = max(0, currentTime - displayAt)
            let remainingHold = max(0, candidate.effectiveHoldSeconds - actualDwell)
            if let nextSameChunkIndex = displayQueue.firstIndex(where: { $0.sequence == candidate.sequence }) {
                displayQueue[nextSameChunkIndex].extraHoldSeconds += remainingHold
            }

            events.append(
                SubtitleEvent(
                    sequence: candidate.sequence,
                    unitIndex: candidate.unitIndex,
                    chunkStart: candidate.chunkStart,
                    chunkEnd: candidate.chunkEnd,
                    processingSeconds: candidate.processingSeconds,
                    displayAt: displayAt,
                    scheduledHoldSeconds: candidate.effectiveHoldSeconds,
                    activeDwellSeconds: actualDwell,
                    usedCatchUpDwell: usedCatchUpDwell,
                    primaryDwellSeconds: 0,
                    totalVisibleSeconds: 0,
                    minimumReadableSeconds: candidate.unit.minimumReadableSeconds,
                    captionStartLagSeconds: max(0, displayAt - candidate.chunkStart),
                    captionEndLagSeconds: max(0, displayAt - candidate.chunkEnd),
                    wordCount: normalizedWords(candidate.unit.text).count,
                    text: candidate.unit.text
                )
            )
        }

        return events
    }

    private func chunkFixture(
        _ fixture: AudioFixture,
        configuration: LiveSubtitleChunkConfiguration
    ) async throws -> [LiveSubtitleAudioChunk] {
        let audioURL = URL(fileURLWithPath: fixture.audioPath)
        let file = try AVAudioFile(forReading: audioURL)
        let format = file.processingFormat
        var chunks: [LiveSubtitleAudioChunk] = []
        var chunkError: AppError?
        let session = try LiveSubtitleCaptureSession(
            format: format,
            configuration: configuration,
            startedAt: Self.timelineBaseDate,
            onChunkReady: { chunk in
                chunks.append(chunk)
            },
            onError: { error in
                chunkError = error
            }
        )

        let frameCapacity = AVAudioFrameCount(max(1, Int(format.sampleRate * 0.04)))
        var frameCursor: AVAudioFramePosition = 0
        while file.framePosition < file.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
                throw EvalError("Could not allocate audio buffer")
            }
            let remaining = AVAudioFrameCount(file.length - file.framePosition)
            try file.read(into: buffer, frameCount: min(frameCapacity, remaining))
            guard buffer.frameLength > 0 else {
                break
            }

            frameCursor += AVAudioFramePosition(buffer.frameLength)
            let receivedAt = Self.timelineBaseDate.addingTimeInterval(TimeInterval(frameCursor) / format.sampleRate)
            session.process(buffer, receivedAt: receivedAt)
        }

        for _ in 0..<4 {
            await Task.yield()
        }

        if let chunkError {
            throw chunkError
        }

        return chunks.sorted { $0.sequence < $1.sequence }
    }

    private func score(
        scenario: EvalScenario,
        preset: String,
        fixture: AudioFixture,
        observedText: String,
        events: [SubtitleEvent],
        failedChunks: [FailedChunk] = [],
        chunkCount: Int,
        holdSeconds: Double
    ) -> ScenarioReport {
        let expectedWords = normalizedWords(fixture.expectedText)
        let observedWords = normalizedWords(observedText)
        let diff = wordDiff(expected: expectedWords, observed: observedWords)
        let blank = blankSpeechMetrics(
            speechIntervals: fixture.speechIntervals,
            visibleIntervals: visibleIntervals(for: events)
        )
        let unreadableEvents = events.filter {
            !$0.usedCatchUpDwell && $0.totalVisibleSeconds + 0.001 < $0.minimumReadableSeconds
        }
        let wordErrorRate = expectedWords.isEmpty ? 0 : Double(diff.distance) / Double(expectedWords.count)
        let missingWordRate = expectedWords.isEmpty ? 0 : Double(diff.deletions) / Double(expectedWords.count)
        let captionStartLags = events.map(\.captionStartLagSeconds)
        let captionEndLags = events.map(\.captionEndLagSeconds)
        let averageCaptionEndLag = average(captionEndLags)
        let longestCaptionEndLag = captionEndLags.max() ?? 0
        let longestCaptionStartLag = captionStartLags.max() ?? 0
        let staleSubtitleCount = events.filter {
            $0.captionEndLagSeconds > LiveSubtitleDisplaySyncPolicy.maximumCaptionEndLagSeconds
        }.count
        let accuracyPassed = wordErrorRate <= 0.03 && missingWordRate <= 0.02
        let capturePassed = failedChunks.isEmpty
        let timingPassed = unreadableEvents.isEmpty && blank.longestBlankWhileSpeechActive <= 0.3
        let syncPassed = longestCaptionEndLag <= LiveSubtitleDisplaySyncPolicy.maximumCaptionEndLagSeconds
            && averageCaptionEndLag <= LiveSubtitleDisplaySyncPolicy.maximumAverageCaptionEndLagSeconds
            && longestCaptionStartLag <= LiveSubtitleDisplaySyncPolicy.maximumCaptionStartLagSeconds

        return ScenarioReport(
            caseID: "\(scenario.id)__\(preset)",
            scenarioID: scenario.id,
            preset: preset,
            fixtureAudioPath: fixture.audioPath,
            audioDuration: fixture.duration,
            holdSeconds: holdSeconds,
            chunkCount: chunkCount,
            failedChunkCount: failedChunks.count,
            subtitleCount: events.count,
            expectedWordCount: expectedWords.count,
            observedWordCount: observedWords.count,
            wordErrorRate: wordErrorRate,
            missingWordRate: missingWordRate,
            insertionCount: diff.insertions,
            deletionCount: diff.deletions,
            substitutionCount: diff.substitutions,
            activeSpeechBlankSeconds: blank.activeSpeechBlankSeconds,
            initialBlankSeconds: blank.initialBlankSeconds,
            longestBlankWhileSpeechActive: blank.longestBlankWhileSpeechActive,
            averageCaptionStartLagSeconds: average(captionStartLags),
            longestCaptionStartLagSeconds: longestCaptionStartLag,
            averageCaptionEndLagSeconds: averageCaptionEndLag,
            longestCaptionEndLagSeconds: longestCaptionEndLag,
            staleSubtitleCount: staleSubtitleCount,
            unreadableSubtitleCount: unreadableEvents.count,
            catchUpDwellSubtitleCount: events.filter(\.usedCatchUpDwell).count,
            shortestPrimaryDwellSeconds: events.map(\.primaryDwellSeconds).min() ?? 0,
            averagePrimaryDwellSeconds: average(events.map(\.primaryDwellSeconds)),
            averageProcessingSeconds: average(events.map(\.processingSeconds)),
            accuracyPassed: accuracyPassed,
            capturePassed: capturePassed,
            timingPassed: timingPassed,
            syncPassed: syncPassed,
            passed: accuracyPassed && capturePassed && timingPassed && syncPassed,
            expectedText: fixture.expectedText,
            observedText: observedText,
            failedChunks: failedChunks,
            events: events
        )
    }

    private func fixture(for scenario: EvalScenario, tts: KokoroTtsManager) async throws -> AudioFixture {
        let fingerprint = stableHash(scenario.fixtureKey(voice: voiceIdentifier))
        let directory = fixturesURL.appendingPathComponent("\(scenario.id)-\(fingerprint)", isDirectory: true)
        let manifestURL = directory.appendingPathComponent("manifest.json")
        let audioURL = directory.appendingPathComponent("combined.wav")

        if fileManager.fileExists(atPath: manifestURL.path), fileManager.fileExists(atPath: audioURL.path) {
            return try decoder.decode(AudioFixture.self, from: Data(contentsOf: manifestURL))
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var outputFile: AVAudioFile?
        var outputFormat: AVAudioFormat?
        var cursor = 0.0
        var intervals: [TimeIntervalRange] = []

        for (index, piece) in scenario.pieces.enumerated() {
            let phraseData = try await tts.synthesize(
                text: piece.text,
                voice: voiceIdentifier,
                voiceSpeed: Float(piece.speed)
            )
            let phraseURL = directory.appendingPathComponent("phrase-\(index).wav")
            try phraseData.write(to: phraseURL, options: .atomic)

            let phraseFile = try AVAudioFile(forReading: phraseURL)
            let phraseFormat = phraseFile.processingFormat
            if outputFile == nil {
                outputFormat = phraseFormat
                outputFile = try AVAudioFile(forWriting: audioURL, settings: phraseFormat.settings)
            }

            guard let outputFile, let outputFormat else {
                throw EvalError("Live subtitle eval did not create an output audio file")
            }
            guard formatsMatch(outputFormat, phraseFormat) else {
                throw EvalError("Kokoro returned inconsistent audio formats inside one fixture")
            }

            let phraseDuration = try appendAudio(from: phraseFile, to: outputFile)
            intervals.append(TimeIntervalRange(start: cursor, end: cursor + phraseDuration))
            cursor += phraseDuration

            let pause = piece.pauseAfter
            if pause > 0 {
                try appendSilence(duration: pause, format: outputFormat, to: outputFile)
                cursor += pause
            }
        }

        if let outputFile, let outputFormat {
            try appendSilence(duration: 2.0, format: outputFormat, to: outputFile)
        }

        let fixture = AudioFixture(
            audioPath: audioURL.path,
            duration: cursor + 2.0,
            expectedText: scenario.expectedText,
            speechIntervals: intervals
        )
        try writeJSON(fixture, to: manifestURL)
        return fixture
    }

    private func makeTTSManager() async throws -> KokoroTtsManager {
        let models = try await TtsModels.download { progress in
            print("Kokoro status: \(progress.phase)")
        }
        let manager = KokoroTtsManager(defaultVoice: voiceIdentifier)
        try await manager.initialize(models: models, preloadVoices: Set([voiceIdentifier]))
        try await manager.setDefaultVoice(voiceIdentifier)
        return manager
    }

    private func makeRunDirectory(kind: String) throws -> (id: String, url: URL) {
        try fileManager.createDirectory(at: runsURL, withIntermediateDirectories: true)
        let id = "\(Self.fileSafeTimestamp())-\(kind)"
        let url = runsURL.appendingPathComponent(id, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try url.path.write(to: latestRunURL, atomically: true, encoding: .utf8)
        return (id, url)
    }

    private func writeSummary(_ summary: RunSummary, to runURL: URL) throws {
        try writeJSON(summary, to: runURL.appendingPathComponent("summary.json"))
    }

    private func writeVerification(summary: RunSummary, to runURL: URL) throws {
        let failedReportCount = verificationFailureCount(summary: summary, runURL: runURL)
        let verification = VerificationReport(
            runID: summary.runID,
            verifiedAt: Date(),
            passed: failedReportCount == 0,
            failedReportCount: failedReportCount,
            accuracyFailedReportCount: summary.aggregate.accuracyFailedReportCount,
            captureFailedReportCount: summary.aggregate.captureFailedReportCount,
            timingFailedReportCount: summary.aggregate.timingFailedReportCount,
            syncFailedReportCount: summary.aggregate.syncFailedReportCount,
            reportCount: summary.reportCount
        )
        try writeJSON(verification, to: runURL.appendingPathComponent("verification.json"))
    }

    private func verificationFailureCount(summary: RunSummary, runURL: URL) -> Int {
        guard !summary.reports.isEmpty else {
            return summary.aggregate.failedReportCount
        }

        var failures = 0
        for relativePath in summary.reports {
            let reportURL = runURL.appendingPathComponent(relativePath)
            guard let data = try? Data(contentsOf: reportURL),
                  let report = try? decoder.decode(ScenarioReport.self, from: data)
            else {
                failures += 1
                continue
            }
            if !report.passed {
                failures += 1
            }
        }
        return failures
    }

    private func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private func pruneRuns(keeping activeID: String) throws {
        guard fileManager.fileExists(atPath: runsURL.path) else {
            return
        }

        let keepLast = intEnvironment("ECHOV_LIVE_SUBTITLE_EVAL_KEEP_LAST") ?? 20
        let maxAgeDays = doubleEnvironment("ECHOV_LIVE_SUBTITLE_EVAL_MAX_RUN_AGE_DAYS") ?? 14
        let now = Date()
        var runDirectories = try fileManager.contentsOfDirectory(
            at: runsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }

        for runURL in runDirectories {
            guard runURL.lastPathComponent != activeID, !isPinned(runURL) else {
                continue
            }
            let modifiedAt = (try? runURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? now
            if now.timeIntervalSince(modifiedAt) > maxAgeDays * 24 * 60 * 60 {
                try fileManager.removeItem(at: runURL)
            }
        }

        runDirectories = try fileManager.contentsOfDirectory(
            at: runsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                && url.lastPathComponent != activeID
                && !isPinned(url)
        }.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate < rhsDate
        }

        let removableCount = max(0, runDirectories.count - max(0, keepLast - 1))
        for runURL in runDirectories.prefix(removableCount) {
            try fileManager.removeItem(at: runURL)
        }
    }

    private func isPinned(_ runURL: URL) -> Bool {
        fileManager.fileExists(atPath: runURL.appendingPathComponent("pinned").path)
    }

    private var voiceIdentifier: String {
        environment["ECHOV_LIVE_SUBTITLE_EVAL_VOICE"] ?? KokoroVoiceCatalog.defaultVoiceID
    }

    private var holdSeconds: Double {
        doubleEnvironment("ECHOV_LIVE_SUBTITLE_EVAL_HOLD_SECONDS") ?? 2.2
    }

    private var maxVisibleLines: Int {
        max(1, min(3, intEnvironment("ECHOV_LIVE_SUBTITLE_EVAL_MAX_LINES") ?? 2))
    }

    private var parakeetModelURL: URL {
        if let path = environment["ECHOV_PARAKEET_MODEL_PATH"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return ParakeetLocalModelLayout.managedModelURL
    }

    private var computeMode: ASRComputeMode {
        if let rawValue = environment["ECHOV_LIVE_SUBTITLE_EVAL_COMPUTE"],
           let mode = ASRComputeMode(rawValue: rawValue) {
            return mode
        }
        return .cpuAndNeuralEngine
    }

    private func selectedScenarios(allWhenUnspecified: Bool) -> [EvalScenario] {
        let scenarios = Self.scenarios
        guard let raw = environment["ECHOV_LIVE_SUBTITLE_EVAL_SCENARIO"], !raw.isEmpty else {
            return allWhenUnspecified ? scenarios : [scenarios[0]]
        }
        if raw == "all" {
            return scenarios
        }
        let selected = Set(raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
        return scenarios.filter { selected.contains($0.id) }
    }

    private func selectedPresets() -> [LiveSubtitleChunkPreset] {
        guard let raw = environment["ECHOV_LIVE_SUBTITLE_EVAL_PRESET"], !raw.isEmpty else {
            return [.balanced]
        }
        if raw == "all" {
            return [.fast, .balanced, .accurate]
        }
        let selected = raw.split(separator: ",").compactMap { LiveSubtitleChunkPreset(rawValue: String($0)) }
        return selected.isEmpty ? [.balanced] : selected
    }

    private func doubleEnvironment(_ key: String) -> Double? {
        environment[key].flatMap(Double.init)
    }

    private func intEnvironment(_ key: String) -> Int? {
        environment[key].flatMap(Int.init)
    }

    private static let timelineBaseDate = Date(timeIntervalSinceReferenceDate: 100_000)

    private static func fileSafeTimestamp() -> String {
        ISO8601DateFormatter()
            .string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    private static let scenarios: [EvalScenario] = [
        EvalScenario(
            id: "normal_narration",
            title: "Normal narration with natural pauses",
            pieces: [
                ScriptPiece(text: "Live subtitles should feel steady and easy to read.", speed: 1.0, pauseAfter: 0.45),
                ScriptPiece(text: "When a speaker finishes a thought, the words should remain on screen long enough to understand them.", speed: 1.0, pauseAfter: 0.55),
                ScriptPiece(text: "The next line should arrive soon, but it should not erase the previous line too aggressively.", speed: 1.0, pauseAfter: 0.35),
                ScriptPiece(text: "This sample uses plain English so the expected transcript is simple to compare.", speed: 1.0, pauseAfter: 0.60),
                ScriptPiece(text: "A good result keeps almost every word and avoids empty space while the speaker is still talking.", speed: 1.0, pauseAfter: 0.40)
            ]
        ),
        EvalScenario(
            id: "slow_pauses",
            title: "Slow speech with longer pauses",
            pieces: [
                ScriptPiece(text: "Now the speaker is talking more slowly.", speed: 0.76, pauseAfter: 1.10),
                ScriptPiece(text: "Each sentence has more room around it.", speed: 0.76, pauseAfter: 1.20),
                ScriptPiece(text: "The subtitle should breathe with the voice.", speed: 0.76, pauseAfter: 1.00),
                ScriptPiece(text: "It should not vanish the moment a pause begins.", speed: 0.76, pauseAfter: 1.30)
            ]
        ),
        EvalScenario(
            id: "fast_continuous",
            title: "Fast continuous speech",
            pieces: [
                ScriptPiece(text: "This speaker moves quickly through several ideas and does not wait for the subtitle system to catch up.", speed: 1.45, pauseAfter: 0.15),
                ScriptPiece(text: "Important words can disappear when forced chunk boundaries are too sharp or the overlap is too small.", speed: 1.45, pauseAfter: 0.12),
                ScriptPiece(text: "The report should show whether fast speech loses words or creates captions that are too brief to read.", speed: 1.45, pauseAfter: 0.15)
            ]
        ),
        EvalScenario(
            id: "youtube_narration",
            title: "Long YouTube-style narration",
            pieces: [
                ScriptPiece(text: "In this section we are going to compare the simple approach with the version that keeps updating while the speaker continues.", speed: 1.12, pauseAfter: 0.12),
                ScriptPiece(text: "The important thing is that the caption on screen should describe the current sentence, not something from half a minute ago.", speed: 1.12, pauseAfter: 0.10),
                ScriptPiece(text: "A viewer can tolerate a small delay from local transcription, but the delay must not keep growing as the video plays.", speed: 1.12, pauseAfter: 0.08),
                ScriptPiece(text: "When there is a pause, the subtitle can rest for a moment so the last idea remains readable.", speed: 1.12, pauseAfter: 0.18),
                ScriptPiece(text: "When the narrator continues, the next caption has to move forward instead of preserving every older line.", speed: 1.12, pauseAfter: 0.10),
                ScriptPiece(text: "This sample keeps the language plain because we want the report to measure timing rather than vocabulary difficulty.", speed: 1.12, pauseAfter: 0.08),
                ScriptPiece(text: "If the display queue is too polite, the lag metric should climb until the report clearly fails.", speed: 1.12, pauseAfter: 0.12),
                ScriptPiece(text: "A good result stays close to the speaker while still leaving enough time to read short captions.", speed: 1.12, pauseAfter: 0.20)
            ]
        ),
        EvalScenario(
            id: "boundary_stress",
            title: "Boundary stress for forced chunk splits",
            pieces: [
                ScriptPiece(
                    text: "Alpha bridge copper delta ember forest garden harbor island jacket kettle lemon mirror nickel orange planet quiet river silver tunnel velvet window yellow zero. The forced boundary should not cut the first or last word near the edge of each audio chunk.",
                    speed: 1.18,
                    pauseAfter: 0.30
                )
            ]
        )
    ]
}

private struct EvalScenario: Codable {
    let id: String
    let title: String
    let pieces: [ScriptPiece]

    var expectedText: String {
        pieces.map(\.text).joined(separator: " ")
    }

    func fixtureKey(voice: String) -> String {
        "\(id)|\(voice)|" + pieces.map { "\($0.text)|\($0.speed)|\($0.pauseAfter)" }.joined(separator: "||")
    }
}

private struct ScriptPiece: Codable {
    let text: String
    let speed: Double
    let pauseAfter: Double
}

private struct AudioFixture: Codable {
    let audioPath: String
    let duration: Double
    let expectedText: String
    let speechIntervals: [TimeIntervalRange]
}

private struct TimeIntervalRange: Codable {
    let start: Double
    let end: Double
}

private struct DisplayCandidate {
    let sequence: Int
    let unitIndex: Int
    let chunkStart: Double
    let chunkEnd: Double
    let processingSeconds: Double
    let enqueueAt: Double
    let unit: LiveSubtitleDisplayUnit
    var extraHoldSeconds: Double = 0

    var effectiveHoldSeconds: Double {
        unit.holdSeconds + extraHoldSeconds
    }
}

private struct SubtitleEvent: Codable {
    let sequence: Int
    let unitIndex: Int
    let chunkStart: Double
    let chunkEnd: Double
    let processingSeconds: Double
    let displayAt: Double
    let scheduledHoldSeconds: Double
    let activeDwellSeconds: Double
    let usedCatchUpDwell: Bool
    let primaryDwellSeconds: Double
    let totalVisibleSeconds: Double
    let minimumReadableSeconds: Double
    let captionStartLagSeconds: Double
    let captionEndLagSeconds: Double
    let wordCount: Int
    let text: String
}

private struct ScenarioReport: Codable {
    let caseID: String
    let scenarioID: String
    let preset: String
    let fixtureAudioPath: String
    let audioDuration: Double
    let holdSeconds: Double
    let chunkCount: Int
    let failedChunkCount: Int
    let subtitleCount: Int
    let expectedWordCount: Int
    let observedWordCount: Int
    let wordErrorRate: Double
    let missingWordRate: Double
    let insertionCount: Int
    let deletionCount: Int
    let substitutionCount: Int
    let activeSpeechBlankSeconds: Double
    let initialBlankSeconds: Double
    let longestBlankWhileSpeechActive: Double
    let averageCaptionStartLagSeconds: Double
    let longestCaptionStartLagSeconds: Double
    let averageCaptionEndLagSeconds: Double
    let longestCaptionEndLagSeconds: Double
    let staleSubtitleCount: Int
    let unreadableSubtitleCount: Int
    let catchUpDwellSubtitleCount: Int
    let shortestPrimaryDwellSeconds: Double
    let averagePrimaryDwellSeconds: Double
    let averageProcessingSeconds: Double
    let accuracyPassed: Bool
    let capturePassed: Bool
    let timingPassed: Bool
    let syncPassed: Bool
    let passed: Bool
    let expectedText: String
    let observedText: String
    let failedChunks: [FailedChunk]
    let events: [SubtitleEvent]

    var relativeReportPath: String {
        "\(caseID)/report.json"
    }
}

private struct FailedChunk: Codable {
    let sequence: Int
    let chunkStart: Double
    let chunkEnd: Double
    let duration: Double
    let reason: String
}

private struct AggregateReport: Codable {
    let averageWordErrorRate: Double
    let averageMissingWordRate: Double
    let totalUnreadableSubtitleCount: Int
    let longestBlankWhileSpeechActive: Double
    let longestCaptionEndLagSeconds: Double
    let longestCaptionStartLagSeconds: Double
    let failedReportCount: Int
    let accuracyFailedReportCount: Int
    let captureFailedReportCount: Int
    let timingFailedReportCount: Int
    let syncFailedReportCount: Int

    init(
        averageWordErrorRate: Double,
        averageMissingWordRate: Double,
        totalUnreadableSubtitleCount: Int,
        longestBlankWhileSpeechActive: Double,
        longestCaptionEndLagSeconds: Double,
        longestCaptionStartLagSeconds: Double,
        failedReportCount: Int,
        accuracyFailedReportCount: Int,
        captureFailedReportCount: Int,
        timingFailedReportCount: Int,
        syncFailedReportCount: Int
    ) {
        self.averageWordErrorRate = averageWordErrorRate
        self.averageMissingWordRate = averageMissingWordRate
        self.totalUnreadableSubtitleCount = totalUnreadableSubtitleCount
        self.longestBlankWhileSpeechActive = longestBlankWhileSpeechActive
        self.longestCaptionEndLagSeconds = longestCaptionEndLagSeconds
        self.longestCaptionStartLagSeconds = longestCaptionStartLagSeconds
        self.failedReportCount = failedReportCount
        self.accuracyFailedReportCount = accuracyFailedReportCount
        self.captureFailedReportCount = captureFailedReportCount
        self.timingFailedReportCount = timingFailedReportCount
        self.syncFailedReportCount = syncFailedReportCount
    }

    static let empty = AggregateReport(
        averageWordErrorRate: 0,
        averageMissingWordRate: 0,
        totalUnreadableSubtitleCount: 0,
        longestBlankWhileSpeechActive: 0,
        longestCaptionEndLagSeconds: 0,
        longestCaptionStartLagSeconds: 0,
        failedReportCount: 0,
        accuracyFailedReportCount: 0,
        captureFailedReportCount: 0,
        timingFailedReportCount: 0,
        syncFailedReportCount: 0
    )

    init(reports: [ScenarioReport]) {
        guard !reports.isEmpty else {
            self = .empty
            return
        }
        averageWordErrorRate = average(reports.map(\.wordErrorRate))
        averageMissingWordRate = average(reports.map(\.missingWordRate))
        totalUnreadableSubtitleCount = reports.reduce(0) { $0 + $1.unreadableSubtitleCount }
        longestBlankWhileSpeechActive = reports.map(\.longestBlankWhileSpeechActive).max() ?? 0
        longestCaptionEndLagSeconds = reports.map(\.longestCaptionEndLagSeconds).max() ?? 0
        longestCaptionStartLagSeconds = reports.map(\.longestCaptionStartLagSeconds).max() ?? 0
        failedReportCount = reports.filter { !$0.passed }.count
        accuracyFailedReportCount = reports.filter { !$0.accuracyPassed }.count
        captureFailedReportCount = reports.filter { !$0.capturePassed }.count
        timingFailedReportCount = reports.filter { !$0.timingPassed }.count
        syncFailedReportCount = reports.filter { !$0.syncPassed }.count
    }
}

private struct RunSummary: Codable {
    let runID: String
    let command: String
    let createdAt: Date
    let scenarioCount: Int
    let reportCount: Int
    let aggregate: AggregateReport
    let reports: [String]
}

private struct VerificationReport: Codable {
    let runID: String
    let verifiedAt: Date
    let passed: Bool
    let failedReportCount: Int
    let accuracyFailedReportCount: Int
    let captureFailedReportCount: Int
    let timingFailedReportCount: Int
    let syncFailedReportCount: Int
    let reportCount: Int
}

private struct DryRunManifest: Codable {
    let scenarios: [EvalScenario]
    let presets: [String]
    let holdSeconds: Double
    let maxVisibleLines: Int
    let voiceIdentifier: String
}

private struct WordDiff {
    let distance: Int
    let insertions: Int
    let deletions: Int
    let substitutions: Int
}

private struct BlankSpeechMetrics {
    let activeSpeechBlankSeconds: Double
    let initialBlankSeconds: Double
    let longestBlankWhileSpeechActive: Double
}

private struct EvalError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private final class ConverterReadState: @unchecked Sendable {
    var error: Error?
}

private extension LiveSubtitleChunkDefaults {
    var configuration: LiveSubtitleChunkConfiguration {
        LiveSubtitleChunkConfiguration(
            maxChunkSeconds: maxChunkSeconds,
            silenceTimeoutSeconds: silenceTimeoutSeconds,
            minimumSpeechSeconds: minimumSpeechSeconds,
            preRollSeconds: preRollSeconds,
            overlapSeconds: overlapSeconds,
            sensitivity: sensitivity
        )
    }
}

private func normalizeForASR(_ audioURL: URL) throws -> URL {
    let inputFile = try AVAudioFile(forReading: audioURL)
    guard let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    ) else {
        throw EvalError("Could not create 16 kHz mono ASR format")
    }

    guard let converter = AVAudioConverter(from: inputFile.processingFormat, to: outputFormat) else {
        throw EvalError("Could not create ASR audio converter")
    }

    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("EchoV-LiveSubtitle-ASR-\(UUID().uuidString)")
        .appendingPathExtension("wav")
    let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputFormat.settings)
    var didReachEnd = false
    let readState = ConverterReadState()

    while !didReachEnd {
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 4096) else {
            throw EvalError("Could not allocate ASR output buffer")
        }

        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { requestedPackets, outStatus in
            if readState.error != nil {
                outStatus.pointee = .noDataNow
                return nil
            }

            let remainingFrames = inputFile.length - inputFile.framePosition
            guard remainingFrames > 0 else {
                outStatus.pointee = .endOfStream
                return nil
            }

            let requestedFrames = max(1, AVAudioFramePosition(requestedPackets))
            let frameCount = AVAudioFrameCount(min(requestedFrames, remainingFrames))
            guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFile.processingFormat, frameCapacity: frameCount) else {
                readState.error = EvalError("Could not allocate ASR input buffer")
                outStatus.pointee = .noDataNow
                return nil
            }

            do {
                try inputFile.read(into: inputBuffer, frameCount: frameCount)
            } catch {
                readState.error = error
                outStatus.pointee = .noDataNow
                return nil
            }

            guard inputBuffer.frameLength > 0 else {
                outStatus.pointee = .endOfStream
                return nil
            }

            outStatus.pointee = .haveData
            return inputBuffer
        }

        if let readError = readState.error {
            throw readError
        }
        if let conversionError {
            throw conversionError
        }
        if outputBuffer.frameLength > 0 {
            try outputFile.write(from: outputBuffer)
        }

        switch status {
        case .haveData, .inputRanDry:
            continue
        case .endOfStream:
            didReachEnd = true
        case .error:
            throw EvalError("ASR audio conversion failed")
        @unknown default:
            didReachEnd = true
        }
    }

    return outputURL
}

private func appendAudio(from input: AVAudioFile, to output: AVAudioFile) throws -> Double {
    let format = input.processingFormat
    let frameCapacity: AVAudioFrameCount = 4096
    let startingFrame = output.length
    while input.framePosition < input.length {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            throw EvalError("Could not allocate phrase audio buffer")
        }
        let remaining = AVAudioFrameCount(input.length - input.framePosition)
        try input.read(into: buffer, frameCount: min(frameCapacity, remaining))
        guard buffer.frameLength > 0 else {
            break
        }
        try output.write(from: buffer)
    }
    return TimeInterval(output.length - startingFrame) / format.sampleRate
}

private func appendSilence(duration: Double, format: AVAudioFormat, to output: AVAudioFile) throws {
    guard duration > 0 else {
        return
    }

    var remainingFrames = AVAudioFramePosition((duration * format.sampleRate).rounded())
    let frameCapacity: AVAudioFrameCount = 4096
    while remainingFrames > 0 {
        let frameCount = AVAudioFrameCount(min(AVAudioFramePosition(frameCapacity), remainingFrames))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw EvalError("Could not allocate silence buffer")
        }
        buffer.frameLength = frameCount
        zero(buffer)
        try output.write(from: buffer)
        remainingFrames -= AVAudioFramePosition(frameCount)
    }
}

private func zero(_ buffer: AVAudioPCMBuffer) {
    guard let channels = buffer.floatChannelData else {
        return
    }

    let byteCount = Int(buffer.frameLength) * MemoryLayout<Float>.size
    for channel in 0..<Int(buffer.format.channelCount) {
        memset(channels[channel], 0, byteCount)
    }
}

private func formatsMatch(_ lhs: AVAudioFormat, _ rhs: AVAudioFormat) -> Bool {
    lhs.channelCount == rhs.channelCount
        && abs(lhs.sampleRate - rhs.sampleRate) < 0.001
        && lhs.commonFormat == rhs.commonFormat
}

private func applyDisplayCancellation(_ events: [SubtitleEvent]) -> [SubtitleEvent] {
    let firstDisplayByLaterChunk = Dictionary(
        grouping: events,
        by: \.sequence
    ).mapValues { grouped in
        grouped.map(\.displayAt).min() ?? .infinity
    }

    return events.filter { event in
        !firstDisplayByLaterChunk.contains { sequence, firstDisplayAt in
            sequence > event.sequence && firstDisplayAt <= event.displayAt
        }
    }.sorted { first, second in
        if first.displayAt == second.displayAt {
            return first.sequence == second.sequence
                ? first.unitIndex < second.unitIndex
                : first.sequence < second.sequence
        }
        return first.displayAt < second.displayAt
    }
}

private func applyVisibilityTiming(to events: [SubtitleEvent], maxVisibleLines: Int) -> [SubtitleEvent] {
    let visibleLineCount = max(1, maxVisibleLines)
    return events.enumerated().map { index, event in
        let eventEnd = event.displayAt + event.scheduledHoldSeconds
        let primaryEnd = min(events[safe: index + 1]?.displayAt ?? eventEnd, eventEnd)
        let rolloutEnd = min(events[safe: index + visibleLineCount]?.displayAt ?? eventEnd, eventEnd)
        return SubtitleEvent(
            sequence: event.sequence,
            unitIndex: event.unitIndex,
            chunkStart: event.chunkStart,
            chunkEnd: event.chunkEnd,
            processingSeconds: event.processingSeconds,
            displayAt: event.displayAt,
            scheduledHoldSeconds: event.scheduledHoldSeconds,
            activeDwellSeconds: event.activeDwellSeconds,
            usedCatchUpDwell: event.usedCatchUpDwell,
            primaryDwellSeconds: max(0, primaryEnd - event.displayAt),
            totalVisibleSeconds: max(0, rolloutEnd - event.displayAt),
            minimumReadableSeconds: event.minimumReadableSeconds,
            captionStartLagSeconds: event.captionStartLagSeconds,
            captionEndLagSeconds: event.captionEndLagSeconds,
            wordCount: event.wordCount,
            text: event.text
        )
    }
}

private func visibleIntervals(for events: [SubtitleEvent]) -> [TimeIntervalRange] {
    var intervals: [TimeIntervalRange] = []
    var currentStart: Double?
    var currentEnd: Double?

    for event in events {
        let eventEnd = event.displayAt + event.totalVisibleSeconds
        guard let start = currentStart, let end = currentEnd else {
            currentStart = event.displayAt
            currentEnd = eventEnd
            continue
        }

        if event.displayAt <= end {
            currentEnd = max(end, eventEnd)
        } else {
            intervals.append(TimeIntervalRange(start: start, end: end))
            currentStart = event.displayAt
            currentEnd = eventEnd
        }
    }

    if let start = currentStart, let end = currentEnd {
        intervals.append(TimeIntervalRange(start: start, end: end))
    }

    return intervals
}

private func blankSpeechMetrics(
    speechIntervals: [TimeIntervalRange],
    visibleIntervals: [TimeIntervalRange]
) -> BlankSpeechMetrics {
    guard let firstDisplay = visibleIntervals.map(\.start).min() else {
        let totalSpeech = speechIntervals.reduce(0) { $0 + max(0, $1.end - $1.start) }
        return BlankSpeechMetrics(
            activeSpeechBlankSeconds: totalSpeech,
            initialBlankSeconds: totalSpeech,
            longestBlankWhileSpeechActive: totalSpeech
        )
    }

    let blankIntervals = complement(of: visibleIntervals, covering: speechIntervals)
    let activeBlank = blankIntervals.reduce(0) { $0 + max(0, $1.end - $1.start) }
    let initialBlank = blankIntervals
        .filter { $0.start < firstDisplay }
        .reduce(0) { $0 + max(0, min($1.end, firstDisplay) - $1.start) }
    let longestAfterFirst = blankIntervals
        .filter { $0.end > firstDisplay }
        .map { max(0, $0.end - max($0.start, firstDisplay)) }
        .max() ?? 0

    return BlankSpeechMetrics(
        activeSpeechBlankSeconds: activeBlank,
        initialBlankSeconds: initialBlank,
        longestBlankWhileSpeechActive: longestAfterFirst
    )
}

private func complement(of visibleIntervals: [TimeIntervalRange], covering speechIntervals: [TimeIntervalRange]) -> [TimeIntervalRange] {
    var blanks: [TimeIntervalRange] = []
    for speech in speechIntervals {
        var cursor = speech.start
        for visible in visibleIntervals where visible.end > speech.start && visible.start < speech.end {
            let clippedStart = max(speech.start, visible.start)
            let clippedEnd = min(speech.end, visible.end)
            if clippedStart > cursor {
                blanks.append(TimeIntervalRange(start: cursor, end: clippedStart))
            }
            cursor = max(cursor, clippedEnd)
        }
        if cursor < speech.end {
            blanks.append(TimeIntervalRange(start: cursor, end: speech.end))
        }
    }
    return blanks
}

private func normalizedWords(_ text: String) -> [String] {
    let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    var words: [String] = []
    var current = ""
    for scalar in folded.unicodeScalars {
        if CharacterSet.alphanumerics.contains(scalar) {
            current.unicodeScalars.append(scalar)
        } else if !current.isEmpty {
            words.append(current)
            current.removeAll(keepingCapacity: true)
        }
    }
    if !current.isEmpty {
        words.append(current)
    }
    return words
}

private func wordDiff(expected: [String], observed: [String]) -> WordDiff {
    let rowCount = expected.count + 1
    let columnCount = observed.count + 1
    var table = Array(
        repeating: DiffCell(distance: 0, insertions: 0, deletions: 0, substitutions: 0),
        count: rowCount * columnCount
    )

    func index(_ row: Int, _ column: Int) -> Int {
        row * columnCount + column
    }

    for row in 1..<rowCount {
        let previous = table[index(row - 1, 0)]
        table[index(row, 0)] = previous.addingDeletion()
    }
    for column in 1..<columnCount {
        let previous = table[index(0, column - 1)]
        table[index(0, column)] = previous.addingInsertion()
    }

    for row in 1..<rowCount {
        for column in 1..<columnCount {
            if expected[row - 1] == observed[column - 1] {
                table[index(row, column)] = table[index(row - 1, column - 1)]
            } else {
                table[index(row, column)] = [
                    table[index(row, column - 1)].addingInsertion(),
                    table[index(row - 1, column)].addingDeletion(),
                    table[index(row - 1, column - 1)].addingSubstitution()
                ].min { lhs, rhs in
                    lhs.distance < rhs.distance
                }!
            }
        }
    }

    let result = table[index(expected.count, observed.count)]
    return WordDiff(
        distance: result.distance,
        insertions: result.insertions,
        deletions: result.deletions,
        substitutions: result.substitutions
    )
}

private struct DiffCell {
    let distance: Int
    let insertions: Int
    let deletions: Int
    let substitutions: Int

    func addingInsertion() -> DiffCell {
        DiffCell(distance: distance + 1, insertions: insertions + 1, deletions: deletions, substitutions: substitutions)
    }

    func addingDeletion() -> DiffCell {
        DiffCell(distance: distance + 1, insertions: insertions, deletions: deletions + 1, substitutions: substitutions)
    }

    func addingSubstitution() -> DiffCell {
        DiffCell(distance: distance + 1, insertions: insertions, deletions: deletions, substitutions: substitutions + 1)
    }
}

private func average(_ values: [Double]) -> Double {
    guard !values.isEmpty else {
        return 0
    }
    return values.reduce(0, +) / Double(values.count)
}

private func stableHash(_ input: String) -> String {
    let digest = SHA256.hash(data: Data(input.utf8))
    return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
