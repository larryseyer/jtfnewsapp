# Multi-Platform Support: iPad + Native macOS

## Context

JTF News is currently an iPhone app (iOS 17+) built with SwiftUI, SwiftData, and no third-party dependencies. The app fetches static files from jtfnews.org and presents stories, daily digest (video/audio), and an archive browser. The goal is to add iPad support verification and a native macOS target for the Mac App Store, sharing as much code as possible.

## Architecture

**Approach**: Single Xcode target with multiplatform support (iOS + macOS), using `#if os()` conditionals for the 4 files that need platform-specific code. All models, services, and content views are shared.

### Platform Matrix

| Component | iOS (iPhone/iPad) | macOS |
|-----------|-------------------|-------|
| Navigation | Bottom tab bar | Sidebar |
| Settings | Gear icon → sheet | Menu bar (Cmd+,) |
| YouTubePlayerView | UIViewRepresentable | NSViewRepresentable |
| BackgroundRefresh | BGTaskScheduler | Not applicable (skipped) |
| Window sizing | System-managed | Min 800x600, default 1000x700 |
| Deployment target | iOS 17.0 | macOS 14.0 |

### Shared Code (no changes needed)

- **Models**: Story, Source, Correction, Channel, ArchivedDay
- **Services**: DataService, FeedService, PodcastService, ArchiveService, AudioManager, SearchIndexer, ConnectivityManager, NotificationManager, GzipUtility
- **Views**: StoriesView, StoryCard, DigestView, AudioPlayerView, MiniPlayerView, ArchiveView, ArchiveSearchView, ArchivedDayView, SettingsView, SourceDetailView, PrivacyPolicyView

## File Changes

### 1. ContentView.swift

Add platform-conditional navigation:

- `#if os(macOS)`: NavigationSplitView with sidebar listing JTF News, Daily Digest, Archive
- `#if os(iOS)`: Keep existing TabView with bottom tabs

### 2. JTFNewsApp.swift

- Add `#if os(macOS)` Settings scene wrapping SettingsView
- Add `.defaultSize(width: 1000, height: 700)` for macOS window
- Add `.windowResizability(.contentMinSize)` with frame min 800x600
- Wrap BackgroundRefreshManager calls in `#if os(iOS)`

### 3. YouTubePlayerView.swift

- `#if os(iOS)`: UIViewRepresentable with UIApplication.shared.open()
- `#if os(macOS)`: NSViewRepresentable with NSWorkspace.shared.open()
- WKWebView configuration and HTML template shared via helper

### 4. BackgroundRefreshManager.swift

- Wrap entire file contents in `#if os(iOS)` / `#endif`
- macOS does not use background app refresh

### 5. project.pbxproj

- Add macOS as a supported platform destination to the existing target
- Set macOS deployment target to 14.0

## Verification

1. Clean Release build and run on iPhone 11 (iOS 18.1) simulator — confirm no regressions
2. Clean Release build and run on iPad simulator — confirm layout works on larger screen
3. Clean Release build and run as native macOS app — confirm sidebar navigation, Settings (Cmd+,), YouTube playback, audio playback, archive browsing all work
