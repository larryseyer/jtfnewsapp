# Watched Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a 4th "Watched" tab that shows only stories matching the user's watched terms, with notification deep linking and a badge count.

**Architecture:** Filter-based approach — queries the same SwiftData store as StoriesView, filters client-side using `WatchedTermsStorage.terms`. Notification taps deep-link to this tab via a `NotificationCenter` post from the `UNUserNotificationCenterDelegate`. Badge count stored in `@AppStorage`.

**Tech Stack:** SwiftUI, SwiftData, UserNotifications, NotificationCenter

---

### Task 1: Add `userInfo` parameter to `NotificationManager.sendNotification()`

**Files:**
- Modify: `JTFNews/Services/NotificationManager.swift:30-43`

- [ ] **Step 1: Add `userInfo` parameter to `sendNotification()`**

Replace the existing method (lines 30-43) with:

```swift
func sendNotification(title: String, body: String, identifier: String, userInfo: [String: String] = [:]) async {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = userInfo

    let request = UNNotificationRequest(
        identifier: identifier,
        content: content,
        trigger: nil // Deliver immediately
    )

    try? await UNUserNotificationCenter.current().add(request)
}
```

- [ ] **Step 2: Build to verify no regressions**

Run: `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED` — all existing callers use the default empty `userInfo`.

- [ ] **Step 3: Commit**

```bash
git add JTFNews/Services/NotificationManager.swift
git commit -m "Add userInfo parameter to sendNotification()"
```

---

### Task 2: Add `didReceive` delegate and notification name

**Files:**
- Modify: `JTFNews/Services/NotificationManager.swift:4-12`

- [ ] **Step 1: Add `Notification.Name` extension**

Add at the top of the file, after the imports (before `NotificationDelegate`):

```swift
extension Notification.Name {
    static let watchedTermsTapped = Notification.Name("watchedTermsTapped")
}
```

- [ ] **Step 2: Add `didReceive` to `NotificationDelegate`**

Add this method inside the `NotificationDelegate` class, after the existing `willPresent` method:

```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
) async {
    let userInfo = response.notification.request.content.userInfo
    if userInfo["type"] as? String == "watchedTerms" {
        NotificationCenter.default.post(name: .watchedTermsTapped, object: nil)
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add JTFNews/Services/NotificationManager.swift
git commit -m "Add didReceive delegate for notification deep linking"
```

---

### Task 3: Pass `userInfo` and badge count from foreground and background callers

**Files:**
- Modify: `JTFNews/Views/Stories/StoriesView.swift:309-321`
- Modify: `JTFNews/Services/BackgroundRefreshManager.swift:137-143`

- [ ] **Step 1: Update foreground caller in StoriesView**

Replace lines 309-321 in `StoriesView.swift` (the foreground watch term check block) with:

```swift
        // Foreground watch term check
        if UserDefaults.standard.bool(forKey: "notifyWatchedTerms"), !fetchedDTOs.isEmpty {
            let matches = WatchedTermMatcher.findNewMatches(in: fetchedDTOs)
            if !matches.isEmpty {
                withAnimation { watchTermMatchCount = matches.count }
                UserDefaults.standard.set(matches.count, forKey: "watchedTabBadge")
                await NotificationManager.shared.sendNotification(
                    title: "Watched Terms",
                    body: "\(matches.count) stor\(matches.count == 1 ? "y matches" : "ies match") your watched terms",
                    identifier: "watched-terms-\(Date().timeIntervalSince1970)",
                    userInfo: ["type": "watchedTerms"]
                )
                WatchedTermMatcher.markAllNotified(hashes: Set(fetchedDTOs.map(\.hash)))
            }
        }
```

- [ ] **Step 2: Update background caller in BackgroundRefreshManager**

Replace lines 137-143 in `BackgroundRefreshManager.swift` (the notification call inside `checkForWatchedTerms()`) with:

```swift
            let matches = WatchedTermMatcher.findNewMatches(in: response.stories)
            if !matches.isEmpty {
                UserDefaults.standard.set(matches.count, forKey: "watchedTabBadge")
                await NotificationManager.shared.sendNotification(
                    title: "Watched Terms",
                    body: "\(matches.count) new stor\(matches.count == 1 ? "y matches" : "ies match") your watched terms",
                    identifier: "watched-terms-\(Date().timeIntervalSince1970)",
                    userInfo: ["type": "watchedTerms"]
                )
            }
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add JTFNews/Views/Stories/StoriesView.swift JTFNews/Services/BackgroundRefreshManager.swift
git commit -m "Pass userInfo and badge count from watch term callers"
```

---

### Task 4: Create WatchedView

**Files:**
- Create: `JTFNews/Views/Watched/WatchedView.swift`
- Modify: `JTFNews.xcodeproj/project.pbxproj` (add to build)

- [ ] **Step 1: Create the WatchedView file**

Create directory and file at `JTFNews/Views/Watched/WatchedView.swift`:

```swift
import SwiftUI
import SwiftData

struct WatchedView: View {
    @Query(sort: \Story.publishedAt, order: .reverse) private var stories: [Story]
    @Query private var corrections: [Correction]
    @Query private var sources: [Source]
    @AppStorage("watchedTabBadge") private var badgeCount = 0
    @State private var showSettings = false

    private var matchingStories: [(story: Story, term: String)] {
        let terms = WatchedTermsStorage.terms
        guard !terms.isEmpty else { return [] }
        let lowercasedTerms = terms.map { $0.lowercased() }

        return stories.compactMap { story in
            let lowFact = story.fact.lowercased()
            guard let term = lowercasedTerms.first(where: { lowFact.contains($0) })
            else { return nil }
            return (story, term)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if WatchedTermsStorage.terms.isEmpty {
                    noTermsView
                } else if matchingStories.isEmpty {
                    noMatchesView
                } else {
                    matchList
                }
            }
            .navigationDestination(for: Story.self) { story in
                let correction = corrections.first { $0.storyId == story.id }
                StoryDetailView(story: story, sources: sources, correction: correction)
            }
            .navigationTitle("Watched")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    WatchedTermsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showSettings = false }
                            }
                        }
                }
            }
        }
        .onAppear { badgeCount = 0 }
    }

    // MARK: - Match List

    private var matchList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(matchingStories, id: \.story.storyHash) { match in
                    let correction = corrections.first { $0.storyId == match.story.id }
                    NavigationLink(value: match.story) {
                        VStack(alignment: .leading, spacing: 8) {
                            StoryCard(story: match.story, sources: sources, correction: correction)

                            Text(match.term.lowercased())
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(.accent)
                                .clipShape(Capsule())
                                .padding(.horizontal, 16)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Empty States

    private var noTermsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Watched Terms")
                .font(.title3)
                .fontWeight(.medium)
            Text("Set up watched terms to track stories that matter to you")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Watched Terms") {
                showSettings = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noMatchesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "eye")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Matches Right Now")
                .font(.title3)
                .fontWeight(.medium)
            Text("No stories match your watched terms right now")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    WatchedView()
        .preferredColorScheme(.dark)
}
```

- [ ] **Step 2: Add to Xcode project**

Add file reference and build file to `JTFNews.xcodeproj/project.pbxproj`:

1. Add PBXBuildFile entry after `AA000001039`:
```
AA000001040 /* WatchedView.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA000002040; };
```

2. Add PBXFileReference entry after `AA000002039`:
```
AA000002040 /* WatchedView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = WatchedView.swift; sourceTree = "<group>"; };
```

3. Add a new PBXGroup for the Watched directory inside the Views group (after the Settings group entry `AA000005012`):
```
AA000005013 /* Watched */ = {
    isa = PBXGroup;
    children = (
        AA000002040 /* WatchedView.swift */,
    );
    path = Watched;
    sourceTree = "<group>";
};
```

4. Add `AA000005013 /* Watched */,` to the Views group children list (after `AA000005012 /* Settings */,`)

5. Add `AA000001040 /* WatchedView.swift in Sources */,` to the PBXSourcesBuildPhase files list

- [ ] **Step 3: Create the directory on disk**

```bash
mkdir -p JTFNews/Views/Watched
```

(The file was already created in Step 1.)

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add -f JTFNews/Views/Watched/WatchedView.swift JTFNews.xcodeproj/project.pbxproj
git commit -m "Add WatchedView — filtered story list for watched terms"
```

---

### Task 5: Add Watched tab to ContentView with badge and deep linking

**Files:**
- Modify: `JTFNews/App/ContentView.swift`

- [ ] **Step 1: Add the Watched tab to iOS body**

In `ContentView.swift`, add the Watched tab inside the `TabView` (after the Archive tab, before the closing `}`), and add `.onReceive` and badge support. Replace the entire `iOSBody` computed property (lines 21-60) with:

```swift
private var iOSBody: some View {
    ZStack(alignment: .bottom) {
        TabView(selection: $selectedTab) {
            StoriesView()
                .tabItem {
                    Label("Stories", systemImage: "newspaper")
                }
                .tag(0)

            DigestView()
                .tabItem {
                    Label("Digest", systemImage: "play.circle")
                }
                .tag(1)

            ArchiveView()
                .tabItem {
                    Label("Archive", systemImage: "archivebox")
                }
                .tag(2)

            WatchedView()
                .tabItem {
                    Label("Watched", systemImage: "eye.fill")
                }
                .tag(3)
                .badge(watchedBadge > 0 ? watchedBadge : 0)
        }

        if audioManager.hasActiveAudio && selectedTab != 1 {
            MiniPlayerView()
                .onTapGesture {
                    selectedTab = 1
                }
                .padding(.bottom, 49) // tab bar height
                .transition(.move(edge: .bottom))
        }
    }
    .environment(audioManager)
    .environment(connectivity)
    .animation(.easeInOut(duration: 0.2), value: audioManager.hasActiveAudio)
    .onAppear { connectivity.start() }
    .onReceive(NotificationCenter.default.publisher(for: .watchedTermsTapped)) { _ in
        selectedTab = 3
    }
    .task {
        ArchiveService.cleanupLegacySearchIndex()
        await ArchiveService(modelContainer: modelContext.container).prefetchAll()
    }
}
```

- [ ] **Step 2: Add `@AppStorage` property to ContentView**

Add this property after the `selectedTab` declaration (line 8):

```swift
@AppStorage("watchedTabBadge") private var watchedBadge = 0
```

- [ ] **Step 3: Add the Watched tab to macOS body**

In the macOS `NavigationSplitView` sidebar list (lines 68-75), add after the Archive tag:

```swift
Label("Watched", systemImage: "eye.fill")
    .tag(3)
```

In the macOS detail `switch` statement (lines 79-86), add a case before `default`:

```swift
case 3:
    WatchedView()
```

Add `.onReceive` to the macOS body, alongside the existing `.onAppear`:

```swift
.onReceive(NotificationCenter.default.publisher(for: .watchedTermsTapped)) { _ in
    selectedTab = 3
}
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add JTFNews/App/ContentView.swift
git commit -m "Add Watched tab to ContentView with badge and deep linking"
```

---

### Task 6: Deploy and verify end-to-end

**Files:** None (verification only)

- [ ] **Step 1: Clean build**

```bash
rm -rf build && xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 2: Deploy to devices**

```bash
./both.sh
```
Expected: Both iPhone and iPad Simulator builds succeed and launch.

- [ ] **Step 3: Manual verification checklist**

1. Open app → 4th tab "Watched" is visible with `eye.fill` icon
2. With terms configured (Iran, Artemis, Trump) → Watched tab shows only matching stories
3. Each matching story shows the matched term as a pill below the card
4. Tapping a story navigates to StoryDetailView
5. Badge count appears on Watched tab icon after pull-to-refresh on Stories tab
6. Visiting the Watched tab clears the badge to 0
7. Remove all terms in Settings → Watched tab shows "No Watched Terms" with "Add Watched Terms" button
8. Tap "Add Watched Terms" → navigates to WatchedTermsView
9. Add terms back, return to Watched tab → matches appear
10. Tap a watched terms notification → app switches to Watched tab
