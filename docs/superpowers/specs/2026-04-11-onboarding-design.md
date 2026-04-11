# First-Run Onboarding — Design Spec

## Problem

New users launch the app with no context about what JTF News is, what makes it different, or what the four tabs do. The app's core value proposition (facts without opinion, source transparency, zero tracking) isn't surfaced until the user discovers it on their own.

## Solution

A full-screen swipe carousel shown once on first launch. 5 pages: a welcome page setting the philosophy, then one page per tab explaining its purpose. Dismissed via "Get Started" on the final page.

## Trigger

- First launch only, gated by `@AppStorage("hasSeenOnboarding")` (default `false`)
- Presented as `.fullScreenCover` from `ContentView`
- Setting `hasSeenOnboarding = true` dismisses the cover and it never appears again

## Visual Style

- Icon + Text: large SF Symbol, gold headline (`#d4af37`), muted description text
- Dark background matching the app's enforced dark mode
- Centered vertically on each page
- SwiftUI `TabView` with `.tabViewStyle(.page)` for horizontal swipe with dot indicators
- "Get Started" button on the last page only

## Pages

| # | SF Symbol | Headline | Description |
|---|-----------|----------|-------------|
| 1 | `checkmark.shield` | Facts Without Opinion | No tracking. No ads. No accounts. Just verified facts from independent sources. |
| 2 | `newspaper` | Verified Stories | Every fact checked against two independent sources with different owners. Source ratings and ownership on every card. |
| 3 | `play.circle` | Daily Digest | Watch or listen to the daily news digest. Video and audio, your choice. |
| 4 | `archivebox` | Full Archive | Browse by date or search across every fact ever published. |
| 5 | `eye` | Watch What Matters | Track stories by keyword. Get notified when matching facts are published. |

## Components

### OnboardingPage (private)

A reusable subview taking `systemImage: String`, `title: String`, `description: String`, and an optional `showButton: Bool`. Renders the icon, headline, description, and conditionally the "Get Started" button.

### OnboardingView

Contains a `TabView` with `.tabViewStyle(.page)` wrapping 5 `OnboardingPage` instances. The `@AppStorage("hasSeenOnboarding")` binding is toggled by the "Get Started" button, which triggers `@Environment(\.dismiss)`.

## Files Changed

| File | Change |
|------|--------|
| `JTFNews/Views/Onboarding/OnboardingView.swift` | New — carousel + OnboardingPage component |
| `JTFNews/App/ContentView.swift` | Add `@AppStorage("hasSeenOnboarding")` + `.fullScreenCover` |
| `JTFNews.xcodeproj/project.pbxproj` | Add file + Onboarding group |

## What We Do NOT Add

- No new data models
- No network requests
- No images or assets (SF Symbols only — no copyright concerns)
- No skip button (5 pages is fast enough)
- No analytics or tracking of onboarding completion

## Verification

1. Build: `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build`
2. Fresh install (delete app first) → onboarding appears
3. Swipe through all 5 pages → dot indicators update
4. Tap "Get Started" on page 5 → onboarding dismisses, app shows Stories tab
5. Kill and relaunch → onboarding does NOT appear again
6. Deploy to iPhone via `./both.sh` and verify on device
