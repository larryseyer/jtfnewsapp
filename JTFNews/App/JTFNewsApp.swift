import SwiftUI
import SwiftData

@main
struct JTFNewsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Story.self,
            Source.self,
            Correction.self,
            Channel.self,
            ArchivedStory.self,
            Bookmark.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        #if os(iOS)
        BackgroundRefreshManager.register()
        #endif
        Task { await NotificationManager.shared.setupDelegate() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 800, minHeight: 600)
                #endif
                .onAppear {
                    #if os(iOS)
                    BackgroundRefreshManager.scheduleRefresh()
                    #endif
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .modelContainer(sharedModelContainer)
        }
        #endif
    }
}
