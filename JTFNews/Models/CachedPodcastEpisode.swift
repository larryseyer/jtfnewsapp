import Foundation
import SwiftData

@Model
final class CachedPodcastEpisode {
    @Attribute(.unique) var id: String
    var title: String
    var date: Date
    var audioURL: String
    var duration: String
    var hasAudio: Bool
    var lastSeenAt: Date

    init(id: String, title: String, date: Date, audioURL: String, duration: String, hasAudio: Bool, lastSeenAt: Date = .now) {
        self.id = id
        self.title = title
        self.date = date
        self.audioURL = audioURL
        self.duration = duration
        self.hasAudio = hasAudio
        self.lastSeenAt = lastSeenAt
    }
}
