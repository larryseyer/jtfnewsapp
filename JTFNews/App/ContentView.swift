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

                SavedView()
                    .tabItem {
                        Label("Saved", systemImage: "bookmark.fill")
                    }
                    .tag(3)

                WatchedView()
                    .tabItem {
                        Label("Watched", systemImage: "eye.fill")
                    }
                    .tag(4)
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
            selectedTab = 4
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
        }
        .onChange(of: hasSeenOnboarding) { _, newValue in
            // Guarantee a fresh stories fetch once onboarding dismisses —
            // the underlying StoriesView's `.task` can be deferred by
            // `fullScreenCover` on first launch, and that's why a brand-new
            // install previously showed a single story until manual refresh.
            if newValue {
                NotificationCenter.default.post(name: .forceStoriesRefresh, object: nil)
            }
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
                Label("Saved", systemImage: "bookmark.fill")
                    .tag(3)
                Label("Watched", systemImage: "eye.fill")
                    .tag(4)
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
                    SavedView()
                case 4:
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
            selectedTab = 4
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .sheet(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
                .frame(width: 500, height: 600)
        }
        .onChange(of: hasSeenOnboarding) { _, newValue in
            if newValue {
                NotificationCenter.default.post(name: .forceStoriesRefresh, object: nil)
            }
        }
    }
    #endif

    // MARK: - Deep Links

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "jtfnews" else { return }

        switch url.host {
        case "stories":
            selectedTab = 0
        case "story":
            let storyId = url.lastPathComponent
            let watchedTerms = WatchedTermsStorage.terms
            let context = ModelContext(modelContext.container)
            let descriptor = FetchDescriptor<Story>(
                predicate: #Predicate { $0.id == storyId }
            )
            if let story = try? context.fetch(descriptor).first {
                let matchesWatched = watchedTerms.contains { term in
                    story.fact.localizedCaseInsensitiveContains(term)
                }
                selectedTab = matchesWatched ? 4 : 0
            } else {
                selectedTab = 0
            }
        default:
            selectedTab = 0
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
