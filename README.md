# JTF News iOS App

Native iOS, macOS, and watchOS app for [JTF News](https://jtfnews.org) — Just the Facts News.

A unified mobile surface for reading verified facts, watching/listening to the daily digest, searching the full archive, and tracking stories by keyword.

## Features

**Stories** — Today's verified facts with multi-source accuracy ratings (0-10 scale) and ownership metadata on every card. Corrections shown inline with original vs. corrected text. Context menu on every card for sharing and bookmarking.

**Digest** — Daily digest with video (YouTube embed) and audio (Archive.org podcast) toggle. Lock screen / Control Center playback controls. Floating mini player across all tabs.

**Archive** — Calendar date browser + full-text search across all archived days. The 30 most recent days are prefetched on launch for instant access.

**Watched** — Track stories by keyword (up to 10 terms). Dedicated tab shows only matching stories with term badges. Tapping a watched terms notification deep-links directly to this tab.

**Saved** — Bookmark stories for later reading. Dedicated tab with swipe-to-delete management.

**Notifications** — Local, on-device notifications for:
- Breaking facts (stories published in the last hour)
- Corrections (new corrections posted)
- Watched terms (stories matching your keywords)

All notifications are off by default. Background refresh checks every 15 minutes. Foreground matching runs on every story fetch.

**Live Activities & Dynamic Island** — When new stories arrive, a Lock Screen banner and Dynamic Island presence show the latest fact count and headline. Auto-dismisses after 5 minutes. Opt-in via Settings.

**Home Screen Widgets** — Small, medium, and large WidgetKit widgets showing today's verified facts at a glance. Tap any story to deep-link into the app.

**Share Sheet** — Polished share text with accuracy ratings, source ownership, and a link to jtfnews.org. Context menu on every story card.

**Siri Shortcuts** — "Hey Siri, what are today's facts?" Returns today's verified stories via voice — no need to open the app.

**Apple Watch** — Standalone watchOS app that fetches stories directly from jtfnews.org. Story list with source ratings in brand gold. WidgetKit complications for watch faces (story count, latest headline, inline summary).

**Source Transparency** — Every story card shows source names, accuracy ratings, and ownership. Tap into any source for detailed 4-part ratings (accuracy, bias, speed, consensus) and ownership classification.

**Support** — Link to the JTF News support page (GitHub Sponsors) in Settings. No ads, no in-app purchases.

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
- **UI:** SwiftUI (iOS, macOS, watchOS)
- **Persistence:** SwiftData (iOS 17+)
- **Search:** SwiftData `@Query` with `localizedStandardContains` predicates
- **Networking:** URLSession with per-endpoint cooldowns (no third-party HTTP libs)
- **Audio:** AVFoundation + MPNowPlayingInfoCenter
- **Video:** WKWebView (YouTube embed)
- **Widgets:** WidgetKit (iOS home screen + watchOS complications)
- **Live Activities:** ActivityKit (iOS Lock Screen + Dynamic Island)
- **Siri:** App Intents framework
- **Compression:** Apple Compression framework (gzip decompression for archives)
- **Minimum targets:** iOS 17, macOS 14, watchOS 10

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

# Build for macOS
xcodebuild -scheme JTFNews -destination 'platform=macOS' build

# Build for watchOS Simulator
xcodebuild -scheme "JTFNewsWatch Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build

# Run tests
xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' test

# Deploy to iPhone + iPad Simulator
./both.sh
```

## Project Structure

```
JTFNews/
  App/            Entry point, tab router, SwiftData config
  Models/         Story, Correction, Source, ArchivedStory, Bookmark, Channel,
                  JTFNewsActivityAttributes
  Services/       DataService, FeedService, PodcastService, ArchiveService,
                  AudioManager, NotificationManager, BackgroundRefreshManager,
                  ConnectivityManager, WatchedTermMatcher, LiveActivityManager,
                  FetchCooldown, ArchiveLineParser
  Views/
    Stories/       StoriesView, StoryDetailView, StoryCard, SourceCard
    Digest/        DigestView, AudioPlayerView, YouTubePlayerView, MiniPlayerView
    Archive/       ArchiveView, ArchiveSearchView
    Saved/         SavedView
    Watched/       WatchedView
    Settings/      SettingsView, WatchedTermsView, SourceDetailView, PrivacyPolicyView
    Onboarding/    OnboardingView
  Shortcuts/       GetTodaysFactsIntent, JTFNewsShortcuts
  Utilities/       GzipUtility, TermExtractor, ShareTextBuilder

JTFNewsWidget/
  Widget extension with small/medium/large widgets, Live Activity, timeline provider

JTFNewsWatch/
  Standalone watchOS app with story list, complications, self-fetching data service
```

## Related

- [JTF News Website](https://jtfnews.org)
- [JTF News Production Repo](https://github.com/JTFNews/jtfnews)
- [Whitepaper](https://jtfnews.org/whitepaper.html)
- [Support JTF News](https://jtfnews.org/support.html)

## License

CC-BY-SA 4.0 — see [LICENSE](LICENSE)
