import SwiftUI
import SwiftData

@main
struct JTFNewsApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Story.self,
            Source.self,
            Correction.self,
            Channel.self,
            ArchivedStory.self,
            Bookmark.self
        ])
        let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.org.jtfnews.app")!
            .appending(path: "JTFNews.sqlite")
        let config = ModelConfiguration(
            schema: schema,
            url: containerURL,
            allowsSave: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        UserDefaults.standard.register(defaults: [
            "useCustomNotificationSound": true
        ])
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
                #if os(iOS)
                .onChange(of: scenePhase) { _, newPhase in
                    // Foreground catch-up: BGAppRefreshTask is opportunistic
                    // on iOS and may never fire on older devices. Running the
                    // notification checks when the app becomes active is the
                    // only way to guarantee the user sees new facts/
                    // corrections they missed while the app was closed.
                    if newPhase == .active {
                        BackgroundRefreshManager.performForegroundCheck()
                    }
                }
                #endif
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
