import SwiftUI
import SwiftData

struct StoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Story.publishedAt, order: .reverse) private var stories: [Story]
    @Query private var corrections: [Correction]
    @Query private var sources: [Source]
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if stories.isEmpty && !hasLoadedOnce {
                    loadingView
                } else if stories.isEmpty {
                    emptyView
                } else {
                    storyList
                }
            }
            .navigationTitle("Stories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
                await refresh()
                hasLoadedOnce = true
            }
        }
    }

    // MARK: - Story List

    private var storyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(stories, id: \.hash) { story in
                    let correction = corrections.first { $0.storyId == story.id }
                    StoryCard(story: story, sources: sources, correction: correction)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .refreshable {
            await refresh(force: true)
        }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Refresh

    private func refresh(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        let dataService = DataService(modelContainer: modelContext.container)
        let feedService = FeedService(modelContainer: modelContext.container)

        do {
            if force {
                UserDefaults.standard.removeObject(forKey: "lastStoriesFetch")
                UserDefaults.standard.removeObject(forKey: "lastCorrectionsFetch")
            }
            try await dataService.fetchStories()
            try await dataService.fetchCorrections()
            try await feedService.fetchSources()
        } catch {
            // Gracefully handle — cached data will display
        }
    }
}

#Preview {
    StoriesView()
        .preferredColorScheme(.dark)
}
