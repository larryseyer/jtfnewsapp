import SwiftUI

struct ArchiveSearchView: View {
    @Environment(SearchIndexer.self) private var searchIndexer
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var results: [SearchResult] = []

    var body: some View {
        VStack(spacing: 0) {
            if searchIndexer.isIndexing {
                HStack(spacing: 8) {
                    ProgressView(value: searchIndexer.indexProgress)
                        .frame(width: 80)
                        .tint(.blue)
                    Text("Indexing archive... \(Int(searchIndexer.indexProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            if searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Search across all archived stories")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if searchIndexer.isIndexing {
                        Text("Indexing in progress — results may be incomplete")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No results for \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if searchIndexer.isIndexing {
                        Text("Still indexing — try again shortly")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(results) { result in
                            NavigationLink(value: result.date) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(result.factText)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)

                                    HStack(spacing: 6) {
                                        Text(result.date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if !result.sourceInfo.isEmpty {
                                            Text("·")
                                                .foregroundStyle(.tertiary)
                                            Text(result.sourceInfo)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(white: 0.11).opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Search Archive")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search archive")
        .navigationDestination(for: String.self) { dateString in
            ArchiveDayDetailView(dateString: dateString)
        }
        .onChange(of: searchText) {
            results = searchIndexer.search(query: searchText)
        }
    }
}

/// Shows all stories for a given archived date (used when navigating from search results)
struct ArchiveDayDetailView: View {
    let dateString: String
    @Environment(\.modelContext) private var modelContext
    @State private var stories: [ArchivedStory] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading archive...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !stories.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(stories, id: \.lineHash) { story in
                            storyCard(story)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(dateString)
        .task {
            await loadDay()
        }
    }

    private func loadDay() async {
        let service = ArchiveService(modelContainer: modelContext.container)
        do {
            stories = try await service.fetchDay(dateString: dateString)
        } catch {
            errorMessage = "Archive not available for \(dateString)"
        }
        isLoading = false
    }

    private func storyCard(_ story: ArchivedStory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(story.factText)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            if !story.sources.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(zip(story.sources, story.ratings).enumerated()), id: \.offset) { _, pair in
                        HStack(spacing: 4) {
                            Text(pair.0)
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.8))
                            if let ratingValue = pair.1.components(separatedBy: " ").first {
                                Text(ratingValue)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(white: 0.17).opacity(0.5))
                        .clipShape(Capsule())
                    }
                }
            }

            HStack {
                if let timestamp = story.timestamp {
                    Text(timestamp, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if story.isCorrected {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Corrected")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange.opacity(0.8))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
