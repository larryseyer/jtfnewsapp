import SwiftUI

struct DigestView: View {
    @Environment(ConnectivityManager.self) private var connectivity
    @AppStorage("preferVideoMode") private var preferVideoMode = true
    @State private var episodes: [PodcastEpisode] = []
    @State private var selectedEpisodeId: String?
    @State private var youtubeURL: String?
    @State private var youtubePlaylist: [String: String] = [:]
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Pinned: mode toggle + player
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

                // Scrollable: past episodes
                if episodes.count > 1 {
                    ScrollView {
                        pastEpisodesSection
                            .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Daily Digest")
            .task { await loadContent() }
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
                            Text(episode.date, style: .date)
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

    private func loadContent() async {
        let service = PodcastService()
        do {
            async let eps = service.fetchEpisodes()
            async let ytURL = service.fetchYouTubeURL()
            async let playlist = service.fetchYouTubePlaylist()
            episodes = try await eps
            youtubeURL = try await ytURL
            youtubePlaylist = (try? await playlist) ?? [:]
        } catch {
            // Gracefully handle
        }
        isLoading = false
    }
}

#Preview {
    DigestView()
        .preferredColorScheme(.dark)
}
