import Foundation
@preconcurrency import UserNotifications

/// Presents notifications as banners even when the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

actor NotificationManager {
    static let shared = NotificationManager()
    private let delegate = NotificationDelegate()

    func setupDelegate() {
        UNUserNotificationCenter.current().delegate = delegate
    }

    func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    func sendNotification(title: String, body: String, identifier: String, userInfo: [String: String] = [:]) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
