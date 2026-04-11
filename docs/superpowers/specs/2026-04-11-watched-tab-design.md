# Watched Tab — Dedicated View for Watch Term Matches

## Problem

Users configure watched terms (e.g. "Iran", "Artemis", "Trump") and receive notifications when stories match. But tapping a notification just opens the app to wherever it was — there's no dedicated destination showing only the matched stories.

## Solution

Add a 4th tab ("Watched") that displays only stories matching the user's watched terms. Tapping a watched terms notification deep-links directly to this tab. A badge count on the tab icon indicates new matches.

## Design

### WatchedView (new file)

- Queries all stories from SwiftData via `@Query(sort: \Story.publishedAt, order: .reverse)`
- Filters client-side against `WatchedTermsStorage.terms` using the same case-insensitive substring matching as `WatchedTermMatcher`
- Displays matching stories using the existing `StoryCard` component
- Each card shows which term it matched as a small pill/tag
- Navigates to `StoryDetailView` via the same value-based `NavigationLink` pattern used in `StoriesView`

**Empty states:**
- No terms configured: `eye.slash` icon + "Set up watched terms to track stories that matter to you" + button navigating to WatchedTermsView in Settings
- Terms configured but no matches today: `eye` icon + "No stories match your watched terms right now"

### Tab Integration (ContentView)

- New tab order: Stories | Digest | Archive | **Watched**
- Icon: `eye.fill` (consistent with watch terms iconography in StoryDetailView)
- Badge: `@AppStorage("watchedTabBadge")` integer, displayed via `.badge()` on the tab
  - Set by `StoriesView.refresh()` and `BackgroundRefreshManager.checkForWatchedTerms()` when matches are found
  - Cleared to 0 when user visits the Watched tab (`WatchedView.onAppear`)

### Notification Deep Linking

**Payload:** Add `userInfo: ["type": "watchedTerms"]` to all watched terms notifications (both foreground in `StoriesView` and background in `BackgroundRefreshManager`).

**Tap handler:** Add `userNotificationCenter(_:didReceive:withCompletionHandler:)` to the existing `NotificationDelegate` in `NotificationManager.swift`. When `userInfo["type"] == "watchedTerms"`, post a `Notification.Name.watchedTermsTapped` via `NotificationCenter.default`.

**Tab switch:** `ContentView` observes this notification via `.onReceive()` and sets `selectedTab = 3` (the Watched tab).

**Flow:**
1. Notification arrives (foreground banner or background)
2. User taps it
3. `NotificationDelegate.didReceive` fires, reads `userInfo["type"]`
4. Posts `NotificationCenter.default` notification
5. `ContentView` receives it, switches to Watched tab
6. User sees only their matched stories

## Files Changed

| File | Change |
|------|--------|
| `JTFNews/Views/Watched/WatchedView.swift` | New — filtered story list, empty states, StoryCard reuse |
| `JTFNews/App/ContentView.swift` | Add 4th tab, badge count, `.onReceive` for deep link |
| `JTFNews/Services/NotificationManager.swift` | Add `didReceive` delegate method, `Notification.Name` extension |
| `JTFNews/Services/NotificationManager.swift` | Add `userInfo` parameter to `sendNotification()` |
| `JTFNews/Views/Stories/StoriesView.swift` | Pass `userInfo` + write badge count on match |
| `JTFNews/Services/BackgroundRefreshManager.swift` | Pass `userInfo` + write badge count on match |
| `JTFNews.xcodeproj/project.pbxproj` | Add WatchedView.swift to build sources |

## What We Reuse

- `StoryCard` — existing story card component
- `StoryDetailView` — existing detail view with source transparency
- `WatchedTermMatcher` — shared matching logic (just added)
- `WatchedTermsStorage` — existing UserDefaults-backed term storage
- `@Query` pattern — same SwiftData query approach as StoriesView and ArchiveSearchView

## What We Do NOT Add

- No new data models or SwiftData entities
- No new network requests (filters stories already in the local store)
- No tracking, analytics, or engagement mechanisms
- No changes to the white paper compliance posture

## Verification

1. Build: `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build`
2. Launch app with watched terms configured (Iran, Artemis, Trump)
3. Watched tab shows only matching stories with term pills
4. Badge count appears on Watched tab icon after refresh
5. Visiting the Watched tab clears the badge
6. Remove all terms — empty state guides user to Settings
7. Tap a watched terms notification — app switches to Watched tab
8. Deploy to iPhone via `./both.sh` and verify on device
