import Foundation
import BackgroundTasks
import SwiftData

enum BackgroundRefreshManager {
    static let taskIdentifier = "org.jtfnews.app.refresh"

    static func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleRefresh(task: refreshTask)
        }
    }

    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleRefresh(task: BGAppRefreshTask) {
        scheduleRefresh() // Reschedule for next time

        let taskRunner = Task {
            await performBackgroundCheck()
        }

        task.expirationHandler = {
            taskRunner.cancel()
        }

        Task {
            await taskRunner.value
            task.setTaskCompleted(success: true)
        }
    }

    private static func performBackgroundCheck() async {
        let notifyDigest = UserDefaults.standard.bool(forKey: "notifyDailyDigest")
        let notifyCorrections = UserDefaults.standard.bool(forKey: "notifyCorrections")
        let notifyBreaking = UserDefaults.standard.bool(forKey: "notifyBreakingFacts")

        guard notifyDigest || notifyCorrections || notifyBreaking else { return }

        // Check for new stories
        if notifyBreaking {
            await checkForBreakingFacts()
        }

        // Check for new corrections
        if notifyCorrections {
            await checkForCorrections()
        }

        // Check for new digest
        if notifyDigest {
            await checkForNewDigest()
        }
    }

    private static func checkForBreakingFacts() async {
        do {
            let url = URL(string: "https://jtfnews.org/stories.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(StoriesResponse.self, from: data)

            let oneHourAgo = Date().addingTimeInterval(-3600)
            let lastCheckKey = "lastBreakingCheck"
            let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
            let lastCheckDate = Date(timeIntervalSince1970: lastCheck)

            let newBreaking = response.stories.filter { story in
                if let publishedStr = story.publishedAt {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = formatter.date(from: publishedStr) ?? {
                        formatter.formatOptions = [.withInternetDateTime]
                        return formatter.date(from: publishedStr)
                    }() {
                        return date > oneHourAgo && date > lastCheckDate
                    }
                }
                return false
            }

            if !newBreaking.isEmpty {
                await NotificationManager.shared.sendNotification(
                    title: "Breaking Facts",
                    body: "\(newBreaking.count) new verified fact\(newBreaking.count == 1 ? "" : "s") published",
                    identifier: "breaking-\(Date().timeIntervalSince1970)"
                )
            }

            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
        } catch {
            // Graceful degradation
        }
    }

    private static func checkForCorrections() async {
        do {
            let url = URL(string: "https://jtfnews.org/corrections.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let corrections = try JSONDecoder().decode([CorrectionDTO].self, from: data)

            let lastCountKey = "lastCorrectionCount"
            let lastCount = UserDefaults.standard.integer(forKey: lastCountKey)

            if corrections.count > lastCount && lastCount > 0 {
                let newCount = corrections.count - lastCount
                await NotificationManager.shared.sendNotification(
                    title: "Corrections Posted",
                    body: "\(newCount) new correction\(newCount == 1 ? "" : "s") published",
                    identifier: "corrections-\(Date().timeIntervalSince1970)"
                )
            }

            UserDefaults.standard.set(corrections.count, forKey: lastCountKey)
        } catch {
            // Graceful degradation
        }
    }

    private static func checkForNewDigest() async {
        do {
            let service = PodcastService()
            let episodes = try await service.fetchEpisodes()

            guard let latest = episodes.first else { return }

            let lastDigestKey = "lastDigestID"
            let lastID = UserDefaults.standard.string(forKey: lastDigestKey)

            if lastID != nil && latest.id != lastID {
                await NotificationManager.shared.sendNotification(
                    title: "Daily Digest Ready",
                    body: latest.title,
                    identifier: "digest-\(Date().timeIntervalSince1970)"
                )
            }

            UserDefaults.standard.set(latest.id, forKey: lastDigestKey)
        } catch {
            // Graceful degradation
        }
    }
}
