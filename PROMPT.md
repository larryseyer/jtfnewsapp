You are building the JTF News iOS app. Read CLAUDE.md for project context.

## Your Workflow

1. Read `prd.json` to find the next story where `passes: false` (lowest priority number first)
2. Read `progress.txt` to see what's been done and any patterns learned
3. Implement the story, following ALL acceptance criteria
4. IMPORTANT: Do NOT run builds or tests during this phase — focus only on writing code and git commits
5. If all acceptance criteria are met, update `prd.json`: set `passes: true` for the completed story
6. Update `progress.txt`: add an entry documenting what was done, files changed, and any patterns/learnings for future iterations
7. Commit with `git add -A && git commit -m "APP-XXX: <story title>"`
8. Move to the next story

## Rules

- ONE story at a time. Do not skip ahead.
- If a story requires creating files that don't exist yet, create them
- If you encounter an issue, document it in progress.txt and try to resolve it
- The design spec is at: `/Volumes/MacLive/Users/larryseyer/JTFNews/docs/superpowers/specs/2026-04-06-ios-app-design.md`
- Reference actual data from https://jtfnews.org (stories.json, feed.xml, etc.) to verify your parsing works
- Do NOT run xcodebuild — the ralph.sh verification phase handles builds after all stories pass

## Key Constraints

- NO third-party dependencies except FeedKit (RSS) if XMLParser proves insufficient
- NO analytics, tracking, or crash reporting SDKs
- iOS 17+ minimum, Swift 6, strict concurrency
- Dark mode primary, calm & minimal aesthetic
- All data fetched from jtfnews.org static files — no backend

<promise>COMPLETE</promise>
