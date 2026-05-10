import Foundation

enum DiagnosticLog {
    private static let lock = NSLock()

    static var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport
            .appendingPathComponent("EchoV/Logs", isDirectory: true)
            .appendingPathComponent("echov.log")
    }

    static func write(_ message: @autoclosure () -> String) {
        lock.lock()
        defer { lock.unlock() }

        do {
            let url = fileURL
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let line = "\(timestamp()) \(message())\n"
            let data = Data(line.utf8)

            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            // Diagnostics must never affect app behavior.
        }
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
