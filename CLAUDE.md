# CLAUDE.md - JTF News iOS App

## Project Overview
Native iOS app for JTF News (Just the Facts News). A unified mobile surface for reading verified facts, watching/listening to the daily digest, and searching the full archive.

## Architecture
**Pure Static Consumer** — fetches existing static files from `jtfnews.org` (GitHub Pages). No backend server. No API. No changes to the JTF News production system.

### Data Sources (all from jtfnews.org)
| Endpoint | Purpose |
|----------|---------|
| `stories.json` | Current day's verified stories |
| `feed.xml` | RSS with full source metadata (ratings, ownership) |
| `podcast.xml` | Daily digest audio links (Archive.org) |
| `corrections.json` | Corrections and retractions log |
| `monitor.json` | System health and operational status |
| `archive/index.json` | Index of all archived days |
| `archive/YYYY/YYYY-MM-DD.txt.gz` | Compressed daily story archives |

## Tech Stack
- **Language:** Swift 6 (strict concurrency)
- **UI:** SwiftUI
- **Persistence:** SwiftData (iOS 17+)
- **Search:** SQLite FTS5 (separate DB alongside SwiftData)
- **Networking:** URLSession (no third-party HTTP libs)
- **Audio:** AVFoundation + MPNowPlayingInfoCenter
- **Video:** WKWebView (YouTube embed)
- **RSS:** Native XMLParser or FeedKit
- **Minimum target:** iOS 17

## App Structure
Three-tab navigation:
1. **Stories** — Today's verified facts with source ratings + ownership on every card
2. **Digest** — YouTube video embed + Archive.org audio player with video/audio toggle
3. **Archive** — Calendar date browser + full-text search across indexed archives

## Key Design Principles
- **Calm & minimal** — dark mode primary, muted colors, generous whitespace
- **Transparency front and center** — source ratings and ownership visible on every story card
- **Zero tracking** — no Firebase, no analytics, no crash reporting SDKs, no user accounts
- **Offline support** — stories cached in SwiftData, audio cached on playback, archive indexed locally
- **Channel-aware** — data models parameterized by Channel (ships Global only, structured for future expansion)

## Privacy (Non-Negotiable)
- NO analytics SDKs of any kind
- NO crash reporting services (use Apple's built-in only)
- NO user accounts, login, or authentication
- NO device fingerprinting
- App Store Privacy Label: "Data Not Collected"

## Notifications (v1)
Local notifications via Background App Refresh. No push server.
- Daily Digest Ready (off by default)
- Corrections (off by default)
- Breaking Facts (off by default)

## Ralph Agent Instructions

When running as a Ralph agent (via ralph.sh), follow this workflow:

1. Read `prd.json` to find the next story where `passes: false` (lowest priority number first)
2. Read `progress.txt` to see what's been done and any patterns learned
3. Implement the story, following ALL acceptance criteria
4. IMPORTANT: Do NOT run builds or tests during this phase — focus only on writing code and git commits
5. If all acceptance criteria are met, update `prd.json`: set `passes: true` for the completed story
6. Update `progress.txt`: add an entry documenting what was done, files changed, and any patterns/learnings for future iterations
7. Commit with `git add -A && git commit -m "APP-XXX: <story title>"`
8. Move to the next story

### Rules
- ONE story at a time. Do not skip ahead.
- If a story requires creating files that don't exist yet, create them
- If you encounter an issue, document it in progress.txt and try to resolve it
- Reference actual data from https://jtfnews.org (stories.json, feed.xml, etc.) to verify parsing logic
- Do NOT run xcodebuild — the verification phase handles builds after all stories pass

### Files
- `prd.json` — Product requirements with stories and acceptance criteria
- `progress.txt` — Tracks completed work, patterns learned, and current state
- `PROMPT.md` — The prompt fed to Claude on each Ralph iteration

## Related Projects
- **JTF News production:** `/Volumes/MacLive/Users/larryseyer/JTFNews` (runs on 2012 Intel Mac)
- **Design spec:** `/Volumes/MacLive/Users/larryseyer/JTFNews/docs/superpowers/specs/2026-04-06-ios-app-design.md`
- **JTF News website:** https://jtfnews.org

## Commands
- `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build` — Build for simulator
- `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' test` — Run tests

## License
CC-BY-SA 4.0
