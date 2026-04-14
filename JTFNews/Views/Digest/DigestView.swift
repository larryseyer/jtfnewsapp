import SwiftUI
import SwiftData

struct DigestView: View {
    @Environment(ConnectivityManager.self) private var connectivity
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferVideoMode") private var preferVideoMode = true
    @Query(sort: \CachedPodcastEpisode.date, order: .reverse) private var cachedEpisodes: [CachedPodcastEpisode]
    @State private var selectedEpisodeId: String?
    @State private var youtubeURL: String?
    @State private var youtubePlaylist: [String: String] = [:]
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var feedMismatchBanner: String?
    @State private var didAutoRetryMismatch = false
    @State private var canonicalLastDate: Date?

    /// Renders episode pubDates in the same GMT calendar day as the RSS
    /// `<title>`, not the device's local day. The Daily Digest is scheduled
    /// against UTC midnight — "April 7" has a pubDate of
    /// `2026-04-07 00:00:00 GMT`, which in Texas (CDT, UTC-5) falls on April 6
    /// at 19:00 local time. If we let the formatter slip into local time, the
    /// row title ("April 7") and the row subtitle ("Apr 6") disagree, which
    /// for an app whose brand promise is "Just the Facts" is worse than a
    /// cosmetic bug — it's a factual contradiction on screen.
    ///
    /// We use `DateFormatter` rather than `Date.FormatStyle(... timeZone:)`
    /// because the FormatStyle `timeZone` parameter has no observable effect
    /// for date-only styles (`time: .omitted`) in practice — the rendered
    /// date still reflects `Calendar.current.timeZone`. A plain
    /// `DateFormatter` with an explicit `.timeZone = .gmt` is unambiguous.
    ///
    /// `nonisolated(unsafe)` is defensible here: `DateFormatter` is
    /// documented-thread-safe for reads after iOS 7, and this instance is
    /// configured exactly once at first use and never mutated thereafter.
    nonisolated(unsafe) private static let episodeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeZone = .gmt
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pinnedHeader
                ScrollView {
                    episodesContent
                        .padding(.vertical, 8)
                }
                .refreshable {
                    guard connectivity.isConnected else { return }
                    await loadContent(force: true)
                }
            }
            .onAppear {
                guard hasLoadedOnce,
                      connectivity.isConnected,
                      FetchCooldown.shouldFetch(key: FetchCooldownKey.digest, interval: FetchCooldownInterval.digestShort)
                else { return }
                Task { await loadContent(force: true) }
            }
            .navigationTitle("Daily Digest")
            .task {
                if !hasLoadedOnce {
                    await loadContent(force: true)
                    hasLoadedOnce = true
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active,
                      connectivity.isConnected,
                      FetchCooldown.shouldFetch(key: FetchCooldownKey.digest, interval: FetchCooldownInterval.digestShort)
                else { return }
                Task { await loadContent(force: true) }
            }
            .onChange(of: connectivity.isConnected) { oldValue, newValue in
                guard oldValue == false, newValue == true,
                      hasLoadedOnce,
                      FetchCooldown.shouldFetch(key: FetchCooldownKey.digest, interval: FetchCooldownInterval.digestShort)
                else { return }
                Task { await loadContent(force: true) }
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

            if let banner = feedMismatchBanner {
                Text(banner)
                    .font(.jtfCaption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .onTapGesture { feedMismatchBanner = nil }
            }

            if preferVideoMode {
                videoSection
            } else {
                audioSection
            }

            if feedMismatchBanner == nil,
               FetchCooldown.isStale(for: FetchCooldownKey.digest) || !connectivity.isConnected {
                Text("Updated \(FetchCooldown.relativeLastUpdated(for: FetchCooldownKey.digest) ?? "just now")")
                    .font(.jtfCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var episodesContent: some View {
        if !cachedEpisodes.isEmpty {
            episodesSection
        } else if !isLoading {
            Text("No episodes available")
                .font(.jtfCaption)
                .foregroundStyle(.secondary)
                .padding(.top, 48)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Video

    private var currentVideoURL: String? {
        if let episode = currentVideoEpisode {
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
                        .font(.jtfSubheadline)
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
                    .font(.jtfSubheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            }
        }
    }

    // MARK: - Audio

    private var currentAudioEpisode: CachedPodcastEpisode? {
        cachedEpisodes.first { $0.hasAudio && ($0.id == selectedEpisodeId || selectedEpisodeId == nil) }
            ?? cachedEpisodes.first(where: \.hasAudio)
    }

    private var currentVideoEpisode: CachedPodcastEpisode? {
        cachedEpisodes.first
    }

    private var audioSection: some View {
        Group {
            if let episode = currentAudioEpisode {
                AudioPlayerView(audioURL: episode.audioURL, title: episode.title)
                    .id(episode.id)
                    .padding(.horizontal, 16)
            } else if isLoading {
                ProgressView("Loading audio...")
                    .frame(height: 200)
            } else {
                Text("No audio available today")
                    .font(.jtfSubheadline)
                    .foregroundStyle(.secondary)
                    .frame(height: 100)
            }
        }
    }

    // MARK: - Episodes

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Episodes")
                .font(.jtfHeadline)
                .padding(.horizontal, 16)

            // Show every episode, including the one currently loaded in the
            // player above. The previous design used `dropFirst()` to hide
            // the current episode on the assumption that it was already
            // "represented" by the player, but that turned the list into a
            // misleading "everything except what's playing" view — users
            // reasonably expected a complete episode index and read the top
            // row as the newest. Keeping every episode in the list, with the
            // currently-loaded one marked, removes the ambiguity.
            ForEach(cachedEpisodes) { episode in
                episodeRow(episode)
            }
        }
    }

    @ViewBuilder
    private func episodeRow(_ episode: CachedPodcastEpisode) -> some View {
        if episode.hasAudio {
            let isPlaying = episode.id == currentAudioEpisode?.id
            Button {
                selectedEpisodeId = episode.id
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.jtfCaption)
                        .foregroundStyle(.tint)
                        .frame(width: 16)
                        .opacity(isPlaying ? 1 : 0)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(episode.title)
                            .font(.jtfSubheadline)
                            .fontWeight(isPlaying ? .semibold : .regular)
                            .lineLimit(2)
                        Text(Self.episodeDateFormatter.string(from: episode.date))
                            .font(.jtfCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !episode.duration.isEmpty {
                        Text(episode.duration)
                            .font(.jtfCaption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isPlaying ? Color(white: 0.17).opacity(0.5) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "\(episode.title), now playing" : episode.title)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.jtfCaption)
                    .foregroundStyle(.tertiary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.jtfSubheadline)
                        .lineLimit(2)
                    Text(Self.episodeDateFormatter.string(from: episode.date))
                        .font(.jtfCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Audio pending")
                    .font(.jtfCaption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("\(episode.title), audio pending")
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
    private func loadContent(force: Bool = false, isRetry: Bool = false) async {
        if !isRetry {
            didAutoRetryMismatch = false
        }
        defer { isLoading = false }
        let service = PodcastService()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    let eps = try await service.fetchEpisodes(force: force)
                    await MainActor.run {
                        persistEpisodes(eps)
                        feedMismatchBanner = nil
                        FetchCooldown.markFetched(key: FetchCooldownKey.digest)
                    }
                } catch let error as PodcastFeedError {
                    await MainActor.run {
                        feedMismatchBanner = "Feed is temporarily malformed — showing what we could parse"
                    }
                    print("[DigestView] fetchEpisodes malformed: \(String(reflecting: error))")
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
            group.addTask {
                do {
                    let date = try await service.fetchCanonicalLastDate()
                    await MainActor.run { canonicalLastDate = date }
                } catch {
                    print("[DigestView] fetchCanonicalLastDate failed: \(String(reflecting: error))")
                }
            }
        }

        // Cross-check: is the parsed feed behind what monitor.json claims?
        if let canonical = canonicalLastDate, let newestEpisode = cachedEpisodes.first?.date {
            var gmtCalendar = Calendar(identifier: .gregorian)
            gmtCalendar.timeZone = .gmt
            let canonicalDay = gmtCalendar.startOfDay(for: canonical)
            let newestDay = gmtCalendar.startOfDay(for: newestEpisode)
            if canonicalDay > newestDay {
                if !didAutoRetryMismatch {
                    didAutoRetryMismatch = true
                    await loadContent(force: true, isRetry: true)
                } else {
                    feedMismatchBanner = "Feed is catching up — latest digest is \(Self.episodeDateFormatter.string(from: canonical))"
                }
            }
        }
    }

    // MARK: - Persist

    @MainActor
    private func persistEpisodes(_ fetched: [PodcastEpisode]) {
        let fetchedIDs = Set(fetched.map(\.id))
        let now = Date.now

        for ep in fetched {
            let descriptor = FetchDescriptor<CachedPodcastEpisode>(
                predicate: #Predicate { $0.id == ep.id }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                existing.title = ep.title
                existing.date = ep.date
                existing.audioURL = ep.audioURL
                existing.duration = ep.duration
                existing.hasAudio = ep.hasAudio
                existing.lastSeenAt = now
            } else {
                modelContext.insert(CachedPodcastEpisode(
                    id: ep.id,
                    title: ep.title,
                    date: ep.date,
                    audioURL: ep.audioURL,
                    duration: ep.duration,
                    hasAudio: ep.hasAudio,
                    lastSeenAt: now
                ))
            }
        }

        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let staleDescriptor = FetchDescriptor<CachedPodcastEpisode>(
            predicate: #Predicate { $0.lastSeenAt < sevenDaysAgo }
        )
        if let stale = try? modelContext.fetch(staleDescriptor) {
            for item in stale where !fetchedIDs.contains(item.id) {
                modelContext.delete(item)
            }
        }

        try? modelContext.save()
    }
}

#Preview {
    DigestView()
        .preferredColorScheme(.dark)
}
