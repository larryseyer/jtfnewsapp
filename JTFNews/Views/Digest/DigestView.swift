import SwiftUI

struct DigestView: View {
    @Environment(ConnectivityManager.self) private var connectivity
    @AppStorage("preferVideoMode") private var preferVideoMode = true
    @State private var episodes: [PodcastEpisode] = []
    @State private var selectedEpisodeId: String?
    @State private var youtubeURL: String?
    @State private var youtubePlaylist: [String: String] = [:]
    @State private var isLoading = true
    @State private var hasLoadedOnce = false

    /// The Digest is an inherently UTC-scheduled feed: every episode's pubDate
    /// is `YYYY-MM-DD 00:00:00 GMT`. Rendering those dates in the device's
    /// local timezone makes every row read a day earlier than the episode
    /// title for any user west of GMT, which is how the "off by one" bug
    /// originally surfaced. Forcing `.gmt` here keeps the Past Digests list
    /// consistent with the RSS titles above it and with the UTC date key used
    /// for the YouTube playlist lookup in `currentVideoURL`.
    private static let pastEpisodeFormat = Date.FormatStyle(
        date: .abbreviated,
        time: .omitted,
        timeZone: .gmt
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pinnedHeader
                ScrollView {
                    pastEpisodesContent
                        .padding(.vertical, 8)
                }
                .refreshable {
                    guard connectivity.isConnected else { return }
                    await loadContent(force: true)
                }
            }
            .navigationTitle("Daily Digest")
            .task {
                // First view construction per process lifetime: force a fresh
                // fetch so a cold launch always surfaces the latest episode,
                // bypassing any `max-age=600` response still sitting in
                // `URLCache` from a previous session. Subsequent re-entries
                // into the Digest tab do not re-run this `.task` because
                // SwiftUI keeps TabView children alive, so the only way to
                // refetch after this point is pull-to-refresh.
                if !hasLoadedOnce {
                    await loadContent(force: true)
                    hasLoadedOnce = true
                }
            }
        }
    }

    // MARK: - Layout

    private var pinnedHeader: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $preferVideoMode) {
                Label("Video", systemImage: "video").tag(true)
                Label("Audio", systemImage: "headphones").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            if preferVideoMode {
                videoSection
            } else {
                audioSection
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var pastEpisodesContent: some View {
        if episodes.count > 1 {
            pastEpisodesSection
        } else if !isLoading {
            Text("No past digests")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 48)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Video

    private var currentVideoURL: String? {
        if let episode = currentEpisode {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            let dateKey = formatter.string(from: episode.date)
            if let playlistURL = youtubePlaylist[dateKey] {
                return playlistURL
            }
        }
        return youtubeURL
    }

    private var videoSection: some View {
        Group {
            if !connectivity.isConnected {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Video requires internet connection")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.11).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            } else if let videoURL = currentVideoURL {
                YouTubePlayerView(videoURL: videoURL)
                    .id(videoURL)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
            } else if isLoading {
                ProgressView("Loading video...")
                    .aspectRatio(16/9, contentMode: .fit)
            } else {
                Text("No video available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            }
        }
    }

    // MARK: - Audio

    private var currentEpisode: PodcastEpisode? {
        if let selectedId = selectedEpisodeId {
            return episodes.first { $0.id == selectedId }
        }
        return episodes.first
    }

    private var audioSection: some View {
        Group {
            if let episode = currentEpisode {
                AudioPlayerView(audioURL: episode.audioURL, title: episode.title)
                    .id(episode.id)
                    .padding(.horizontal, 16)
            } else if isLoading {
                ProgressView("Loading audio...")
                    .frame(height: 200)
            } else {
                Text("No audio available today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            }
        }
    }

    // MARK: - Past Episodes

    private var pastEpisodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past Digests")
                .font(.headline)
                .padding(.horizontal, 16)

            ForEach(episodes.dropFirst()) { episode in
                Button {
                    selectedEpisodeId = episode.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.title)
                                .font(.subheadline)
                                .lineLimit(2)
                            Text(episode.date, format: Self.pastEpisodeFormat)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !episode.duration.isEmpty {
                            Text(episode.duration)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedEpisodeId == episode.id ? Color(white: 0.17).opacity(0.5) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Load

    /// Loads episodes, the daily video URL, and the historical YouTube
    /// playlist **independently and in parallel**.
    ///
    /// Each fetch is gated by its own `do/catch` so a single failure — say,
    /// the YouTube playlist scrape hitting a layout change on youtube.com —
    /// never hides successfully-fetched episodes or the video URL. This
    /// mirrors the resilience pattern we use in `StoriesView.refresh`.
    private func loadContent(force: Bool = false) async {
        defer { isLoading = false }
        let service = PodcastService()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    let eps = try await service.fetchEpisodes(force: force)
                    await MainActor.run { episodes = eps }
                } catch {
                    print("[DigestView] fetchEpisodes failed: \(String(reflecting: error))")
                }
            }
            group.addTask {
                do {
                    let url = try await service.fetchYouTubeURL()
                    await MainActor.run { youtubeURL = url }
                } catch {
                    print("[DigestView] fetchYouTubeURL failed: \(String(reflecting: error))")
                }
            }
            group.addTask {
                do {
                    let playlist = try await service.fetchYouTubePlaylist()
                    await MainActor.run { youtubePlaylist = playlist }
                } catch {
                    print("[DigestView] fetchYouTubePlaylist failed: \(String(reflecting: error))")
                }
            }
        }
    }
}

#Preview {
    DigestView()
        .preferredColorScheme(.dark)
}
