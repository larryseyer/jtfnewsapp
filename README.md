# JTF News iOS App

Native iOS and macOS app for [JTF News](https://jtfnews.org) — Just the Facts News.

A unified mobile surface for reading verified facts, watching/listening to the daily digest, searching the full archive, and tracking stories by keyword.

## Features

**Stories** — Today's verified facts with multi-source accuracy ratings (0-10 scale) and ownership metadata on every card. Corrections shown inline with original vs. corrected text.

**Digest** — Daily digest with video (YouTube embed) and audio (Archive.org podcast) toggle. Lock screen / Control Center playback controls. Floating mini player across all tabs.

**Archive** — Calendar date browser + full-text search across all archived days. The 30 most recent days are prefetched on launch for instant access.

**Watched** — Track stories by keyword (up to 10 terms). Dedicated tab shows only matching stories with term badges. Tapping a watched terms notification deep-links directly to this tab.

**Notifications** — Local, on-device notifications for:
- Breaking facts (stories published in the last hour)
- Corrections (new corrections posted)
- Watched terms (stories matching your keywords)

All notifications are off by default. Background refresh checks every 15 minutes. Foreground matching runs on every story fetch.

**Bookmarks** — Save stories for later.

**Source Transparency** — Every story card shows source names, accuracy ratings, and ownership. Tap into any source for detailed 4-part ratings (accuracy, bias, speed, consensus) and ownership classification.

## Architecture

**Pure Static Consumer** — the app fetches existing static files from `jtfnews.org` (GitHub Pages). No backend server. No API. No push notification server.

| Endpoint | Purpose |
|----------|---------|
| `stories.json` | Current day's verified stories |
| `feed.xml` | RSS with source metadata (ratings, ownership) |
| `podcast.xml` | Daily digest audio links (Archive.org) |
| `corrections.json` | Corrections and retractions log |
| `monitor.json` | System health and daily digest YouTube URL |
| `archive/index.json` | Index of all archived days |
| `archive/YYYY/YYYY-MM-DD.txt.gz` | Compressed daily story archives |

## Tech Stack

- **Language:** Swift 6 (strict concurrency)
- **UI:** SwiftUI (iOS + macOS)
- **Persistence:** SwiftData (iOS 17+)
- **Search:** SwiftData `@Query` with `localizedStandardContains` predicates
- **Networking:** URLSession with per-endpoint cooldowns (no third-party HTTP libs)
- **Audio:** AVFoundation + MPNowPlayingInfoCenter
- **Video:** WKWebView (YouTube embed)
- **Compression:** Apple Compression framework (gzip decompression for archives)
- **Minimum target:** iOS 17

## Privacy

- Zero tracking. Zero analytics. Zero user data collected.
- No ads. No in-app purchases. Free.
- No Firebase, no crash reporting SDKs, no user accounts.
- All notification matching is on-device.
- App Store Privacy Label: "Data Not Collected"

## Building

```bash
# Build for iOS Simulator
xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Project Structure

```
JTFNews/
  App/            Entry point, tab router, SwiftData config
  Models/         Story, Correction, Source, ArchivedStory, Bookmark, Channel
  Services/       DataService, FeedService, PodcastService, ArchiveService,
                  AudioManager, NotificationManager, BackgroundRefreshManager,
                  ConnectivityManager, WatchedTermMatcher, FetchCooldown,
                  ArchiveLineParser
  Views/
    Stories/      StoriesView, StoryDetailView, StoryCard, SourceCard
    Digest/       DigestView, AudioPlayerView, YouTubePlayerView, MiniPlayerView
    Archive/      ArchiveView, ArchiveSearchView
    Watched/      WatchedView
    Settings/     SettingsView, WatchedTermsView, SourceDetailView, PrivacyPolicyView
  Utilities/      GzipUtility, TermExtractor
```

## Related

- [JTF News Website](https://jtfnews.org)
- [JTF News Production Repo](https://github.com/JTFNews/jtfnews)
- [Whitepaper](https://jtfnews.org/whitepaper.html)

## License

CC-BY-SA 4.0 — see [LICENSE](LICENSE)
