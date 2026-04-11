import ActivityKit
import Foundation

struct JTFNewsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let storyCount: Int
        let latestFact: String
        let publishedDate: Date
    }
}
