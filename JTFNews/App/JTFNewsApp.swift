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
            ArchivedDay.self
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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onAppear {
                    #if os(iOS)
                    BackgroundRefreshManager.scheduleRefresh()
                    #endif
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
