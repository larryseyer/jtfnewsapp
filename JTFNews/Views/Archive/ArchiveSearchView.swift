import SwiftUI

struct ArchiveSearchView: View {
    @Environment(SearchIndexer.self) private var searchIndexer
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

            if results.isEmpty && !searchText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No results for \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { result in
                    NavigationLink(value: result.date) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.factText)
                                .font(.body)
                                .lineLimit(3)
                            HStack {
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
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $searchText, prompt: "Search archive")
        .onChange(of: searchText) {
            results = searchIndexer.search(query: searchText)
        }
    }
}
