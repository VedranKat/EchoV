import Foundation
@preconcurrency import UserNotifications

final class TextResponseNotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let notificationCenter = UNUserNotificationCenter.current()
    private let onOpenSession: @MainActor @Sendable (UUID) -> Void

    init(onOpenSession: @escaping @MainActor @Sendable (UUID) -> Void) {
        self.onOpenSession = onOpenSession
        super.init()
        notificationCenter.delegate = self
    }

    func post(sessionID: UUID, title: String, responseText: String) {
        let notificationCenter = notificationCenter
        let onOpenSession = onOpenSession
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                Self.addNotification(
                    notificationCenter: notificationCenter,
                    onOpenSession: onOpenSession,
                    sessionID: sessionID,
                    title: title,
                    responseText: responseText
                )
            case .notDetermined:
                notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        Self.addNotification(
                            notificationCenter: notificationCenter,
                            onOpenSession: onOpenSession,
                            sessionID: sessionID,
                            title: title,
                            responseText: responseText
                        )
                    } else {
                        Task { @MainActor in
                            onOpenSession(sessionID)
                        }
                    }
                }
            case .denied:
                Task { @MainActor in
                    onOpenSession(sessionID)
                }
            @unknown default:
                Task { @MainActor in
                    onOpenSession(sessionID)
                }
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let sessionIDString = response.notification.request.content.userInfo["sessionID"] as? String
        let onOpenSession = onOpenSession
        if let sessionIDString, let sessionID = UUID(uuidString: sessionIDString) {
            Task { @MainActor in
                onOpenSession(sessionID)
            }
        }
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    private static func addNotification(
        notificationCenter: UNUserNotificationCenter,
        onOpenSession: @escaping @MainActor @Sendable (UUID) -> Void,
        sessionID: UUID,
        title: String,
        responseText: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "EchoV"
        content.subtitle = title
        content.body = Self.notificationBody(from: responseText)
        content.sound = .default
        content.userInfo = ["sessionID": sessionID.uuidString]

        let request = UNNotificationRequest(
            identifier: "text-response-\(sessionID.uuidString)",
            content: content,
            trigger: nil
        )
        notificationCenter.add(request) { error in
            guard error != nil else {
                return
            }

            Task { @MainActor in
                onOpenSession(sessionID)
            }
        }
    }

    private static func notificationBody(from responseText: String) -> String {
        let cleaned = responseText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count > 180 else {
            return cleaned
        }

        let endIndex = cleaned.index(cleaned.startIndex, offsetBy: 180)
        return "\(cleaned[..<endIndex])..."
    }
}
