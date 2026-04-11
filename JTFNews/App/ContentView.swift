import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var audioManager = AudioManager()
    @State private var connectivity = ConnectivityManager()
    @State private var selectedTab = 0
    @AppStorage("watchedTabBadge") private var watchedBadge = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        #if os(macOS)
        macOSBody
        #else
        iOSBody
        #endif
    }

    // MARK: - iOS

    #if os(iOS)
    private var iOSBody: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                StoriesView()
                    .tabItem {
                        Label("Stories", systemImage: "newspaper")
                    }
                    .tag(0)

                DigestView()
                    .tabItem {
                        Label("Digest", systemImage: "play.circle")
                    }
                    .tag(1)

                ArchiveView()
                    .tabItem {
                        Label("Archive", systemImage: "archivebox")
                    }
                    .tag(2)

                WatchedView()
                    .tabItem {
                        Label("Watched", systemImage: "eye.fill")
                    }
                    .tag(3)
                    .badge(watchedBadge > 0 ? watchedBadge : 0)
            }

            if audioManager.hasActiveAudio && selectedTab != 1 {
                MiniPlayerView()
                    .onTapGesture {
                        selectedTab = 1
                    }
                    .padding(.bottom, 49) // tab bar height
                    .transition(.move(edge: .bottom))
            }
        }
        .environment(audioManager)
        .environment(connectivity)
        .animation(.easeInOut(duration: 0.2), value: audioManager.hasActiveAudio)
        .onAppear { connectivity.start() }
        .task {
            ArchiveService.cleanupLegacySearchIndex()
            await ArchiveService(modelContainer: modelContext.container).prefetchAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchedTermsTapped)) { _ in
            selectedTab = 3
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
        }
    }
    #endif

    // MARK: - macOS

    #if os(macOS)
    private var macOSBody: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("JTF News", systemImage: "newspaper")
                    .tag(0)
                Label("Daily Digest", systemImage: "play.circle")
                    .tag(1)
                Label("Archive", systemImage: "archivebox")
                    .tag(2)
                Label("Watched", systemImage: "eye.fill")
                    .tag(3)
            }
            .navigationTitle("JTF News")
        } detail: {
            ZStack(alignment: .bottom) {
                switch selectedTab {
                case 1:
                    DigestView()
                case 2:
                    ArchiveView()
                case 3:
                    WatchedView()
                default:
                    StoriesView()
                }

                if audioManager.hasActiveAudio && selectedTab != 1 {
                    MiniPlayerView()
                        .onTapGesture {
                            selectedTab = 1
                        }
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .environment(audioManager)
        .environment(connectivity)
        .animation(.easeInOut(duration: 0.2), value: audioManager.hasActiveAudio)
        .onAppear { connectivity.start() }
        .task {
            ArchiveService.cleanupLegacySearchIndex()
            await ArchiveService(modelContainer: modelContext.container).prefetchAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchedTermsTapped)) { _ in
            selectedTab = 3
        }
        .sheet(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
                .frame(width: 500, height: 600)
        }
    }
    #endif
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
