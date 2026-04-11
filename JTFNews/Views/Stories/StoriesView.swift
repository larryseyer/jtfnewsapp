import SwiftUI
import SwiftData

struct StoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ConnectivityManager.self) private var connectivity
    @Query(sort: \Story.publishedAt, order: .reverse) private var stories: [Story]
    @Query private var corrections: [Correction]
    @Query private var sources: [Source]
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var showSettings = false
    @State private var showOfflineToast = false

    var body: some View {
        NavigationStack {
            Group {
                if stories.isEmpty && !hasLoadedOnce && !connectivity.isConnected {
                    offlineEmptyView
                } else if stories.isEmpty && !hasLoadedOnce {
                    loadingView
                } else if stories.isEmpty {
                    emptyView
                } else {
                    storyList
                }
            }
            .navigationDestination(for: Story.self) { story in
                let correction = corrections.first { $0.storyId == story.id }
                StoryDetailView(story: story, sources: sources, correction: correction)
            }
            .navigationTitle("JTF News")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .task {
            if !hasLoadedOnce {
                // First view construction per process lifetime: force a fresh
                // fetch so a cold launch always surfaces the latest stories,
                // corrections, and source metadata regardless of any in-session
                // cooldown state left in UserDefaults from a prior run.
                await refresh(force: true)
                hasLoadedOnce = true
            }
        }
    }

    // MARK: - Story List

    private var storyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let lastUpdated = lastUpdatedText, !connectivity.isConnected || isStale {
                    HStack(spacing: 6) {
                        if !connectivity.isConnected {
                            Image(systemName: "wifi.slash")
                                .font(.caption2)
                        }
                        Text("Last updated \(lastUpdated)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                }

                ForEach(stories, id: \.storyHash) { story in
                    let correction = corrections.first { $0.storyId == story.id }
                    NavigationLink(value: story) {
                        StoryCard(story: story, sources: sources, correction: correction)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable {
            if connectivity.isConnected {
                await refresh(force: true)
            } else {
                showOfflineToast = true
            }
        }
        .overlay(alignment: .top) {
            if showOfflineToast {
                Text("No internet connection")
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { showOfflineToast = false }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showOfflineToast)
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading stories...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "newspaper")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Stories Available")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("Pull down to refresh")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .padding(.top, 100)
        }
        .refreshable {
            if connectivity.isConnected {
                await refresh(force: true)
            } else {
                showOfflineToast = true
            }
        }
        .overlay(alignment: .top) {
            if showOfflineToast {
                Text("No internet connection")
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { showOfflineToast = false }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showOfflineToast)
    }

    // MARK: - Offline Empty

    private var offlineEmptyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Internet Connection")
                    .font(.title3)
                    .fontWeight(.medium)
                Text("Pull down to refresh when connected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 300)
            .padding(.top, 100)
        }
        .refreshable {
            if connectivity.isConnected {
                await refresh(force: true)
            } else {
                showOfflineToast = true
            }
        }
        .overlay(alignment: .top) {
            if showOfflineToast {
                Text("No internet connection")
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { showOfflineToast = false }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showOfflineToast)
    }

    // MARK: - Helpers

    private var lastUpdatedText: String? {
        let timestamp = UserDefaults.standard.double(forKey: FetchCooldownKey.stories)
        guard timestamp > 0 else { return nil }
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Stories are considered stale ~2× the server's 30-minute publish cadence.
    /// With a 15-minute in-session cooldown, anything older than ~20 minutes
    /// in the UI genuinely is stale — show the "Last updated …" header to
    /// signal that the user is looking at cached content.
    private var isStale: Bool {
        let timestamp = UserDefaults.standard.double(forKey: FetchCooldownKey.stories)
        guard timestamp > 0 else { return true }
        return Date().timeIntervalSince1970 - timestamp > 20 * 60
    }

    // MARK: - Refresh

    /// Runs all three refresh fetches **in parallel and independently**.
    ///
    /// The previous sequential `do/try/catch` chained all three fetches so a
    /// single throw aborted the rest — meaning one broken endpoint would
    /// silently hide the results of the other two. Stories, corrections, and
    /// sources are independent resources; one failing must never hide another.
    private func refresh(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        if force {
            FetchCooldown.reset(
                FetchCooldownKey.stories,
                FetchCooldownKey.corrections,
                FetchCooldownKey.sources
            )
        }

        let dataService = DataService(modelContainer: modelContext.container)
        let feedService = FeedService(modelContainer: modelContext.container)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do { try await dataService.fetchStories() }
                catch { print("[StoriesView] fetchStories failed: \(String(reflecting: error))") }
            }
            group.addTask {
                do { try await dataService.fetchCorrections() }
                catch { print("[StoriesView] fetchCorrections failed: \(String(reflecting: error))") }
            }
            group.addTask {
                do { try await feedService.fetchSources() }
                catch { print("[StoriesView] fetchSources failed: \(String(reflecting: error))") }
            }
        }
    }
}

#Preview {
    StoriesView()
        .preferredColorScheme(.dark)
}
