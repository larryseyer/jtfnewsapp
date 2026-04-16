import Foundation
@preconcurrency import UserNotifications

extension Notification.Name {
    static let watchedTermsTapped = Notification.Name("watchedTermsTapped")
    /// Posted when onboarding is dismissed so StoriesView can guarantee a
    /// fresh fetch even if its `.task` was deferred behind `fullScreenCover`.
    static let forceStoriesRefresh = Notification.Name("forceStoriesRefresh")
    /// Posted by the macOS ⌘, menu command (and any future trigger) to open
    /// the in-app Settings sheet. The legacy SwiftUI `Settings` scene was
    /// removed so macOS uses the same modal Settings flow as iOS.
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    /// Posted by the macOS "About JTF News" menu command to open the custom
    /// About sheet, replacing AppKit's default minimal panel.
    static let openAboutRequested = Notification.Name("openAboutRequested")
}

/// Presents notifications as banners even when the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if userInfo["type"] as? String == "watchedTerms" {
            NotificationCenter.default.post(name: .watchedTermsTapped, object: nil)
        }
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

    /// Consolidated entry point: collapses up to three category counts from a
    /// single check cycle into ONE notification (one chime). The server
    /// publishes roughly every 30 minutes and the app checks every 15, so the
    /// only realistic source of back-to-back chimes is multiple categories
    /// detected in the same cycle. Single-category cycles preserve today's
    /// exact title and body wording — truth-first, zero regression for the
    /// common case.
    func notify(facts: Int = 0, corrections: Int = 0, watchedTerms: Int = 0) async {
        var clauses: [(category: Category, count: Int)] = []
        if facts        > 0 { clauses.append((.breakingFacts, facts)) }
        if corrections  > 0 { clauses.append((.corrections,   corrections)) }
        if watchedTerms > 0 { clauses.append((.watchedTerms,  watchedTerms)) }
        guard !clauses.isEmpty else { return }

        let title: String
        let body: String
        if clauses.count == 1 {
            let c = clauses[0]
            title = c.category.singleTitle
            body  = c.category.fullBody(count: c.count)
        } else {
            title = "JTF News Update"
            body  = clauses.map { $0.category.shortClause(count: $0.count) }.joined(separator: ", ")
        }

        let userInfo: [String: String] = watchedTerms > 0 ? ["type": "watchedTerms"] : [:]
        let identifier = "jtfnews-cycle-\(Date().timeIntervalSince1970)"
        await sendNotification(title: title, body: body, identifier: identifier, userInfo: userInfo)
    }

    func sendNotification(title: String, body: String, identifier: String, userInfo: [String: String] = [:]) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let useCustomSound = UserDefaults.standard.bool(forKey: "useCustomNotificationSound")
        content.sound = useCustomSound
            ? UNNotificationSound(named: UNNotificationSoundName("JTFNewsChime.caf"))
            : .default
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    private enum Category: Sendable {
        case breakingFacts, corrections, watchedTerms

        var singleTitle: String {
            switch self {
            case .breakingFacts: return "Breaking Facts"
            case .corrections:   return "Corrections Posted"
            case .watchedTerms:  return "Watched Terms"
            }
        }

        func fullBody(count: Int) -> String {
            switch self {
            case .breakingFacts:
                return count == 1
                    ? "1 new verified fact published"
                    : "\(count) new verified facts published"
            case .corrections:
                return count == 1
                    ? "1 new correction published"
                    : "\(count) new corrections published"
            case .watchedTerms:
                return count == 1
                    ? "1 new story matches your watched terms"
                    : "\(count) new stories match your watched terms"
            }
        }

        func shortClause(count: Int) -> String {
            switch self {
            case .breakingFacts:
                return "\(count) new fact\(count == 1 ? "" : "s")"
            case .corrections:
                return "\(count) correction\(count == 1 ? "" : "s")"
            case .watchedTerms:
                return "\(count) watched match\(count == 1 ? "" : "es")"
            }
        }
    }
}
