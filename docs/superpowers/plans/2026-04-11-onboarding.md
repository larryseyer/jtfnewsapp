# First-Run Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a first-run onboarding carousel that introduces JTF News's philosophy and four tabs, shown once on first launch with a re-trigger option in Settings.

**Architecture:** A `TabView` with `.tabViewStyle(.page)` presented as `.fullScreenCover` from `ContentView`, gated by `@AppStorage("hasSeenOnboarding")`. A reusable `OnboardingPage` subview renders each page. A "Show Welcome" button in Settings resets the flag.

**Tech Stack:** SwiftUI, SF Symbols, @AppStorage

---

### Task 1: Create OnboardingView

**Files:**
- Create: `JTFNews/Views/Onboarding/OnboardingView.swift`
- Modify: `JTFNews.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p JTFNews/Views/Onboarding
```

- [ ] **Step 2: Create `JTFNews/Views/Onboarding/OnboardingView.swift`**

```swift
import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                OnboardingPage(
                    systemImage: "checkmark.shield",
                    title: "Facts Without Opinion",
                    description: "No tracking. No ads. No accounts. Just verified facts from independent sources."
                )
                .tag(0)

                OnboardingPage(
                    systemImage: "newspaper",
                    title: "Verified Stories",
                    description: "Every fact checked against two independent sources with different owners. Source ratings and ownership on every card."
                )
                .tag(1)

                OnboardingPage(
                    systemImage: "play.circle",
                    title: "Daily Digest",
                    description: "Watch or listen to the daily news digest. Video and audio, your choice."
                )
                .tag(2)

                OnboardingPage(
                    systemImage: "archivebox",
                    title: "Full Archive",
                    description: "Browse by date or search across every fact ever published."
                )
                .tag(3)

                OnboardingPage(
                    systemImage: "eye",
                    title: "Watch What Matters",
                    description: "Track stories by keyword. Get notified when matching facts are published.",
                    showButton: true
                ) {
                    hasSeenOnboarding = true
                }
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Onboarding Page

private struct OnboardingPage: View {
    let systemImage: String
    let title: String
    let description: String
    var showButton: Bool = false
    var onGetStarted: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 72))
                .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.22)) // #d4af37

            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.22))
                .multilineTextAlignment(.center)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if showButton {
                Button {
                    onGetStarted?()
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.83, green: 0.69, blue: 0.22))
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView()
}
```

- [ ] **Step 3: Add to Xcode project**

Edit `JTFNews.xcodeproj/project.pbxproj`:

1. **PBXBuildFile section** — Add after the line containing `AA000001040`:
```
		AA000001041 /* OnboardingView.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA000002041; };
```

2. **PBXFileReference section** — Add after the line containing `AA000002040`:
```
		AA000002041 /* OnboardingView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = OnboardingView.swift; sourceTree = "<group>"; };
```

3. **New PBXGroup** — Add after the Watched group (`AA000005013`):
```
		AA000005014 /* Onboarding */ = {
			isa = PBXGroup;
			children = (
				AA000002041 /* OnboardingView.swift */,
			);
			path = Onboarding;
			sourceTree = "<group>";
		};
```

4. **Views group children** — In the Views group (`AA000005006`), add `AA000005014 /* Onboarding */,` after `AA000005013 /* Watched */,`

5. **PBXSourcesBuildPhase** — Add `AA000001041 /* OnboardingView.swift in Sources */,` after the line with `AA000001040`

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add -f JTFNews/Views/Onboarding/OnboardingView.swift JTFNews.xcodeproj/project.pbxproj
git commit -m "Add OnboardingView with 5-page swipe carousel"
```

---

### Task 2: Present onboarding from ContentView

**Files:**
- Modify: `JTFNews/App/ContentView.swift`

- [ ] **Step 1: Add `@AppStorage` property**

After line 9 (`@AppStorage("watchedTabBadge") private var watchedBadge = 0`), add:

```swift
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
```

- [ ] **Step 2: Add `.fullScreenCover` to iOS body**

In the `iOSBody` computed property, add this modifier to the `ZStack`, after the existing `.onReceive` modifier (after line 70):

```swift
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
        }
```

- [ ] **Step 3: Add `.fullScreenCover` to macOS body (sheet fallback)**

In the `macOSBody` computed property, add this modifier to the `NavigationSplitView`, after the existing `.onReceive` modifier (after line 122):

```swift
        .sheet(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
                .frame(width: 500, height: 600)
        }
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add JTFNews/App/ContentView.swift
git commit -m "Present onboarding as fullScreenCover on first launch"
```

---

### Task 3: Add "Show Welcome" button in Settings

**Files:**
- Modify: `JTFNews/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Add `@AppStorage` property**

After line 12 (`@AppStorage("archiveDownloadMode") private var archiveDownloadMode = "wifi"`), add:

```swift
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
```

- [ ] **Step 2: Add "Show Welcome" button to the aboutSection**

In the `aboutSection` computed property, add this after the `NavigationLink("Privacy Policy")` block (after line 121) and before the `HStack` with "Version":

```swift
            Button("Show Welcome") {
                hasSeenOnboarding = false
                dismiss()
            }
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild -scheme JTFNews -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | grep -E "error:|BUILD"`
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add JTFNews/Views/Settings/SettingsView.swift
git commit -m "Add Show Welcome button to Settings for re-triggering onboarding"
```

---

### Task 4: Deploy and verify end-to-end

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

1. Fresh install (delete app first) → onboarding carousel appears full-screen
2. Swipe through all 5 pages → dot indicators update correctly
3. Page 1: shield icon + "Facts Without Opinion" + philosophy text
4. Page 2: newspaper icon + "Verified Stories" + source transparency text
5. Page 3: play icon + "Daily Digest" + video/audio text
6. Page 4: archivebox icon + "Full Archive" + search text
7. Page 5: eye icon + "Watch What Matters" + "Get Started" button
8. Tap "Get Started" → onboarding dismisses, Stories tab visible
9. Kill and relaunch → onboarding does NOT appear again
10. Settings → About → tap "Show Welcome" → settings dismisses → onboarding reappears
11. Complete onboarding again → back to normal app
