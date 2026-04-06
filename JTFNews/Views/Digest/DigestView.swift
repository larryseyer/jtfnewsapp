import SwiftUI

struct DigestView: View {
    @Environment(ConnectivityManager.self) private var connectivity
    @AppStorage("preferVideoMode") private var preferVideoMode = true
    @State private var episodes: [PodcastEpisode] = []
    @State private var youtubeURL: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Mode toggle
                    Picker("Mode", selection: $preferVideoMode) {
                        Label("Video", systemImage: "video").tag(true)
                        Label("Audio", systemImage: "headphones").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    // Current digest
                    if preferVideoMode {
                        videoSection
                    } else {
                        audioSection
                    }

                    // Past episodes
                    if episodes.count > 1 {
                        pastEpisodesSection
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Digest")
            .task { await loadContent() }
        }
    }

    // MARK: - Video

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
                .background(Color(.systemGray6).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            } else if let youtubeURL {
                YouTubePlayerView(videoURL: youtubeURL)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
            } else if isLoading {
                ProgressView("Loading video...")
                    .frame(height: 220)
            } else {
                Text("No video available today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            }
        }
    }

    // MARK: - Audio

    private var audioSection: some View {
        Group {
            if let episode = episodes.first {
                AudioPlayerView(audioURL: episode.audioURL, title: episode.title)
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
            }
        }
    }

    // MARK: - Load

    private func loadContent() async {
        let service = PodcastService()
        do {
            async let eps = service.fetchEpisodes()
            async let ytURL = service.fetchYouTubeURL()
            episodes = try await eps
            youtubeURL = try await ytURL
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
