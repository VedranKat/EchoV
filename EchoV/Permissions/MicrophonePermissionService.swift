import AppKit
import AVFoundation

struct MicrophonePermissionService: Sendable {
    func authorizationStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    @MainActor
    func openPrivacySettings() {
        prepareRelaunchAfterPrivacyRestart()

        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    @MainActor
    private func prepareRelaunchAfterPrivacyRestart() {
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            """
            pid="$1"
            app="$2"
            deadline="$(($(date +%s) + 300))"
            while kill -0 "$pid" 2>/dev/null; do
              if [ "$(date +%s)" -ge "$deadline" ]; then
                exit 0
              fi
              sleep 0.2
            done
            /usr/bin/open "$app"
            """,
            "echov-relaunch",
            String(ProcessInfo.processInfo.processIdentifier),
            appURL.path
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
    }
}
