import SwiftUI

// MARK: - Archived Story Parser

private struct ArchivedStory: Identifiable {
    let id = UUID()
    let timestamp: Date?
    let sources: [String]
    let ratings: [String]
    let isCorrected: Bool
    let factText: String

    static func parse(from text: String) -> [ArchivedStory] {
        text.components(separatedBy: "\n")
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .compactMap { parseLine($0) }
    }

    private static func parseLine(_ line: String) -> ArchivedStory? {
        let parts = line.components(separatedBy: "|")
        guard parts.count >= 6 else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = isoFormatter.date(from: parts[0])

        let sources = parts[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let ratings = parts[2].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let isCorrected = parts[3].contains("[CORRECTED]")
        let factText = parts[5...].joined(separator: "|").trimmingCharacters(in: .whitespaces)

        guard !factText.isEmpty else { return nil }
        return ArchivedStory(timestamp: timestamp, sources: sources, ratings: ratings, isCorrected: isCorrected, factText: factText)
    }
}

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var availableDates: [String] = []
    @State private var archiveText: String?
    @State private var isLoadingIndex = true
    @State private var isLoadingDay = false
    @State private var errorMessage: String?
    @State private var showSearch = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)

                Divider()

                contentArea
            }
            .navigationTitle("Archive")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Today") {
                        selectedDate = Date()
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .navigationDestination(isPresented: $showSearch) {
                ArchiveSearchView()
            }
            .task {
                await loadIndex()
                await loadDay()
            }
            .onChange(of: selectedDate) {
                Task { await loadDay() }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if isLoadingDay {
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
        } else if let text = archiveText {
            let stories = ArchivedStory.parse(from: text)
            if stories.isEmpty {
                ScrollView {
                    Text(text)
                        .font(.body)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(stories) { story in
                            archivedStoryCard(story)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "archivebox")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Select a date to view archived stories")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Archived Story Card

    private func archivedStoryCard(_ story: ArchivedStory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Fact text
            Text(story.factText)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            // Sources with ratings
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

            // Bottom row: time + correction indicator
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

    // MARK: - Load

    private func loadIndex() async {
        let service = ArchiveService(modelContainer: modelContext.container)
        do {
            availableDates = try await service.fetchIndex()
        } catch {
            // Graceful degradation
        }
        isLoadingIndex = false
    }

    private func loadDay() async {
        let dateString = dateFormatter.string(from: selectedDate)
        isLoadingDay = true
        errorMessage = nil
        archiveText = nil

        let service = ArchiveService(modelContainer: modelContext.container)
        do {
            archiveText = try await service.fetchDay(dateString: dateString)
        } catch {
            errorMessage = "Archive not available for \(dateString)"
        }
        isLoadingDay = false
    }
}

#Preview {
    ArchiveView()
        .preferredColorScheme(.dark)
}
