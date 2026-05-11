import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class PermissionState {
    var microphoneAuthorizationStatus: AVAuthorizationStatus
    var isAccessibilityTrusted: Bool
    var startupStatus: StartupRegistrationStatus
    var onPermissionsChanged: (() -> Void)?

    init(
        microphoneAuthorizationStatus: AVAuthorizationStatus = .notDetermined,
        isAccessibilityTrusted: Bool = false,
        startupStatus: StartupRegistrationStatus = .notRegistered
    ) {
        self.microphoneAuthorizationStatus = microphoneAuthorizationStatus
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.startupStatus = startupStatus
    }

    func refresh(
        microphonePermission: MicrophonePermissionService,
        accessibilityPermission: AccessibilityPermissionService,
        startupPermission: StartupPermissionService
    ) {
        let microphoneAuthorizationStatus = microphonePermission.authorizationStatus()
        let isAccessibilityTrusted = accessibilityPermission.isTrusted()
        let startupStatus = startupPermission.status()

        guard
            self.microphoneAuthorizationStatus != microphoneAuthorizationStatus ||
                self.isAccessibilityTrusted != isAccessibilityTrusted ||
                self.startupStatus != startupStatus
        else {
            return
        }

        self.microphoneAuthorizationStatus = microphoneAuthorizationStatus
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.startupStatus = startupStatus
        onPermissionsChanged?()
    }
}
