import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupIdentifier = "group.org.jtfnews.app"

    static var containerURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appending(path: "JTFNews.sqlite")
    }

    static func create() throws -> ModelContainer {
        let schema = Schema([
            Story.self,
            Source.self,
            Correction.self,
            Channel.self,
            ArchivedStory.self,
            Bookmark.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            url: containerURL,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Read-only container for widget extension (prevents accidental writes)
    static func createReadOnly() throws -> ModelContainer {
        let schema = Schema([
            Story.self,
            Source.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            url: containerURL,
            allowsSave: false
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
