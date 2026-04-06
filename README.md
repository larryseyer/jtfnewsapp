# JTF News iOS App

Native iOS app for [JTF News](https://jtfnews.org) — Just the Facts News.

A unified mobile surface for reading verified facts, watching/listening to the daily digest, and searching the full archive.

## Architecture

Pure Static Consumer — the app fetches existing static files from `jtfnews.org` (GitHub Pages). No backend server. No API.

- **Stories** from `stories.json` and `feed.xml`
- **Daily Digest video** from YouTube
- **Daily Digest audio** from Archive.org
- **Archive** from compressed daily `.txt.gz` files
- **Corrections** from `corrections.json`

## Tech Stack

- Swift 6 / SwiftUI
- SwiftData (persistence + offline cache)
- SQLite FTS5 (full-text archive search)
- AVFoundation (podcast audio + Now Playing)
- WKWebView (YouTube embed)
- iOS 17+ minimum

## Philosophy

- Zero tracking. Zero analytics. Zero user data.
- No ads. No in-app purchases. Free.
- App Store Privacy Label: "Data Not Collected"
- Open source (CC-BY-SA 4.0)

## Related

- [JTF News Website](https://jtfnews.org)
- [JTF News Production Repo](https://github.com/JTFNews/jtfnews)
- [Design Spec](https://github.com/JTFNews/jtfnews/blob/main/docs/superpowers/specs/2026-04-06-ios-app-design.md)

## License

CC-BY-SA 4.0 — see [LICENSE](LICENSE)
