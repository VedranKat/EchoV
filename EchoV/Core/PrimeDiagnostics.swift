import Foundation

actor PrimeDiagnostics {
    static let defaultsKey = "PrimeDiagnosticsEnabled"

    private static let shared = PrimeDiagnostics()

    private var cleanupRequestCount = 0
    private var llamaRequestCount = 0

    static func isEnabled(userDefaults: UserDefaults = .standard) -> Bool {
        #if ECHOV_DEV_DIAGNOSTICS
        userDefaults.bool(forKey: defaultsKey)
        #else
        false
        #endif
    }

    static func nextCleanupRequestID() async -> Int? {
        #if ECHOV_DEV_DIAGNOSTICS
        guard isEnabled() else {
            return nil
        }

        return await shared.makeCleanupRequestID()
        #else
        return nil
        #endif
    }

    static func nextLlamaRequestID() async -> Int? {
        #if ECHOV_DEV_DIAGNOSTICS
        guard isEnabled() else {
            return nil
        }

        return await shared.makeLlamaRequestID()
        #else
        return nil
        #endif
    }

    static func writeCleanupCompleted(
        requestID: Int?,
        engine: String,
        inputChars: Int,
        promptChars: Int,
        maxTokens: Int,
        outputChars: Int,
        duration: TimeInterval
    ) {
        #if ECHOV_DEV_DIAGNOSTICS
        guard let requestID, isEnabled() else {
            return
        }

        DiagnosticLog.write(
            cleanupCompletedLine(
                requestID: requestID,
                engine: engine,
                inputChars: inputChars,
                promptChars: promptChars,
                maxTokens: maxTokens,
                outputChars: outputChars,
                duration: duration
            )
        )
        #endif
    }

    static func writeCleanupFailed(
        requestID: Int?,
        engine: String,
        inputChars: Int,
        promptChars: Int,
        maxTokens: Int,
        duration: TimeInterval,
        reason: String
    ) {
        #if ECHOV_DEV_DIAGNOSTICS
        guard let requestID, isEnabled() else {
            return
        }

        DiagnosticLog.write(
            cleanupFailedLine(
                requestID: requestID,
                engine: engine,
                inputChars: inputChars,
                promptChars: promptChars,
                maxTokens: maxTokens,
                duration: duration,
                reason: reason
            )
        )
        #endif
    }

    static func writeLlamaCompleted(
        requestID: Int?,
        model: String,
        pid: Int32?,
        serverAge: TimeInterval?,
        serverRequestCount: Int,
        promptChars: Int,
        maxTokens: Int,
        outputChars: Int,
        firstDuration: TimeInterval,
        retryDuration: TimeInterval?,
        totalDuration: TimeInterval,
        emptyResponseDetail: String?
    ) {
        #if ECHOV_DEV_DIAGNOSTICS
        guard let requestID, isEnabled() else {
            return
        }

        DiagnosticLog.write(
            llamaCompletedLine(
                requestID: requestID,
                model: model,
                pid: pid,
                serverAge: serverAge,
                serverRequestCount: serverRequestCount,
                promptChars: promptChars,
                maxTokens: maxTokens,
                outputChars: outputChars,
                firstDuration: firstDuration,
                retryDuration: retryDuration,
                totalDuration: totalDuration,
                emptyResponseDetail: emptyResponseDetail
            )
        )
        #endif
    }

    static func writeLlamaFailed(
        requestID: Int?,
        model: String,
        pid: Int32?,
        serverAge: TimeInterval?,
        serverRequestCount: Int,
        promptChars: Int,
        maxTokens: Int,
        firstDuration: TimeInterval?,
        retryDuration: TimeInterval?,
        totalDuration: TimeInterval,
        reason: String,
        emptyResponseDetail: String?
    ) {
        #if ECHOV_DEV_DIAGNOSTICS
        guard let requestID, isEnabled() else {
            return
        }

        DiagnosticLog.write(
            llamaFailedLine(
                requestID: requestID,
                model: model,
                pid: pid,
                serverAge: serverAge,
                serverRequestCount: serverRequestCount,
                promptChars: promptChars,
                maxTokens: maxTokens,
                firstDuration: firstDuration,
                retryDuration: retryDuration,
                totalDuration: totalDuration,
                reason: reason,
                emptyResponseDetail: emptyResponseDetail
            )
        )
        #endif
    }

    static func cleanupCompletedLine(
        requestID: Int,
        engine: String,
        inputChars: Int,
        promptChars: Int,
        maxTokens: Int,
        outputChars: Int,
        duration: TimeInterval
    ) -> String {
        "PrimeDiagnostics cleanup completed id=\(requestID) engine=\(quoted(engine)) inputChars=\(inputChars) promptChars=\(promptChars) maxTokens=\(maxTokens) outputChars=\(outputChars) durationMs=\(milliseconds(duration))"
    }

    static func cleanupFailedLine(
        requestID: Int,
        engine: String,
        inputChars: Int,
        promptChars: Int,
        maxTokens: Int,
        duration: TimeInterval,
        reason: String
    ) -> String {
        "PrimeDiagnostics cleanup failed id=\(requestID) engine=\(quoted(engine)) inputChars=\(inputChars) promptChars=\(promptChars) maxTokens=\(maxTokens) durationMs=\(milliseconds(duration)) reason=\(quoted(reason))"
    }

    static func llamaCompletedLine(
        requestID: Int,
        model: String,
        pid: Int32?,
        serverAge: TimeInterval?,
        serverRequestCount: Int,
        promptChars: Int,
        maxTokens: Int,
        outputChars: Int,
        firstDuration: TimeInterval,
        retryDuration: TimeInterval?,
        totalDuration: TimeInterval,
        emptyResponseDetail: String?
    ) -> String {
        [
            "PrimeDiagnostics llama completed",
            "id=\(requestID)",
            "model=\(quoted(model))",
            "pid=\(pid.map { String($0) } ?? "none")",
            "serverAgeMs=\(optionalMilliseconds(serverAge))",
            "serverRequestCount=\(serverRequestCount)",
            "promptChars=\(promptChars)",
            "maxTokens=\(maxTokens)",
            "outputChars=\(outputChars)",
            "firstDurationMs=\(milliseconds(firstDuration))",
            "retryCount=\(retryDuration == nil ? 0 : 1)",
            "retryDurationMs=\(optionalMilliseconds(retryDuration))",
            "totalDurationMs=\(milliseconds(totalDuration))",
            "emptyResponse=\(quoted(emptyResponseDetail ?? "none"))"
        ].joined(separator: " ")
    }

    static func llamaFailedLine(
        requestID: Int,
        model: String,
        pid: Int32?,
        serverAge: TimeInterval?,
        serverRequestCount: Int,
        promptChars: Int,
        maxTokens: Int,
        firstDuration: TimeInterval?,
        retryDuration: TimeInterval?,
        totalDuration: TimeInterval,
        reason: String,
        emptyResponseDetail: String?
    ) -> String {
        [
            "PrimeDiagnostics llama failed",
            "id=\(requestID)",
            "model=\(quoted(model))",
            "pid=\(pid.map { String($0) } ?? "none")",
            "serverAgeMs=\(optionalMilliseconds(serverAge))",
            "serverRequestCount=\(serverRequestCount)",
            "promptChars=\(promptChars)",
            "maxTokens=\(maxTokens)",
            "firstDurationMs=\(optionalMilliseconds(firstDuration))",
            "retryCount=\(retryDuration == nil ? 0 : 1)",
            "retryDurationMs=\(optionalMilliseconds(retryDuration))",
            "totalDurationMs=\(milliseconds(totalDuration))",
            "reason=\(quoted(reason))",
            "emptyResponse=\(quoted(emptyResponseDetail ?? "none"))"
        ].joined(separator: " ")
    }

    private func makeCleanupRequestID() -> Int {
        cleanupRequestCount += 1
        return cleanupRequestCount
    }

    private func makeLlamaRequestID() -> Int {
        llamaRequestCount += 1
        return llamaRequestCount
    }

    private static func optionalMilliseconds(_ interval: TimeInterval?) -> String {
        guard let interval else {
            return "none"
        }

        return "\(milliseconds(interval))"
    }

    private static func milliseconds(_ interval: TimeInterval) -> Int {
        max(0, Int((interval * 1000).rounded()))
    }

    private static func quoted(_ value: String) -> String {
        let sanitized = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        return "\"\(sanitized)\""
    }
}
