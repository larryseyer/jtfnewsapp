# App Store Submission Plan — iOS + Mac App Store

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Submit JTF News 1.0 to both the iOS App Store and Mac App Store.

**Architecture:** The app is already built and running on iOS 17+ (iPhone/iPad) and macOS 14+. We need to: fix build configuration (entitlements, icon, signing), create a privacy page on the website, capture screenshots, build release archives, and upload to App Store Connect.

**Tech Stack:** Xcode 16, xcodebuild, xcrun altool/notarytool, GitHub Pages

---

## Pre-Flight: Items the Developer Must Do in App Store Connect (Manual)

Before running this plan, the developer must complete these steps in a browser at https://appstoreconnect.apple.com:

1. **Create the app record** (if not done):
   - Apps > "+" > New App
   - Platform: iOS + macOS
   - Name: "JTF News"
   - Primary Language: English (U.S.)
   - Bundle ID: `org.jtfnews.app`
   - SKU: `jtfnews-app`

2. **Note your Team ID** — Go to https://developer.apple.com/account > Membership Details. Copy the Team ID (10-character alphanumeric string). You'll need it for Task 2.

---

### Task 1: Create Privacy Policy Page on jtfnews.org

**Context:** Apple requires a publicly accessible privacy policy URL. The in-app privacy policy exists in `PrivacyPolicyView.swift` but there's no web version. The website lives at `/Volumes/MacLive/Users/larryseyer/JTFNews/docs/`.

**Files:**
- Create: `/Volumes/MacLive/Users/larryseyer/JTFNews/docs/privacy.html`
- Reference: `/Users/larryseyer/jtfnewsapp/JTFNews/Views/Settings/PrivacyPolicyView.swift` (content source)
- Reference: `/Volumes/MacLive/Users/larryseyer/JTFNews/docs/support.html` (style reference)

- [ ] **Step 1: Read the existing support.html for page structure/style**

```bash
head -50 /Volumes/MacLive/Users/larryseyer/JTFNews/docs/support.html
```

Use the same HTML structure, CSS references, header/footer pattern.

- [ ] **Step 2: Read PrivacyPolicyView.swift for privacy policy content**

The in-app privacy policy has the exact text. Extract the section titles and body text from the SwiftUI view.

- [ ] **Step 3: Create privacy.html**

Create `/Volumes/MacLive/Users/larryseyer/JTFNews/docs/privacy.html` matching the website's existing style. Content must include:

- **Data Collection:** "JTF News does not collect, store, or transmit any personal data. Period."
- **Network Requests:** "The app connects only to jtfnews.org to fetch publicly available news data (stories, corrections, podcasts, and archive files). No data is sent from your device."
- **On-Device Storage:** "Stories and search indexes are stored locally on your device using Apple's SwiftData framework. This data never leaves your device."
- **No Third-Party SDKs:** "JTF News contains zero third-party SDKs. No analytics (no Firebase, no Mixpanel), no crash reporting services, no ad networks, no tracking pixels."
- **Notifications:** "All notifications are local, triggered by Background App Refresh. No push notification servers are used."
- **App Store Privacy Label:** "Data Not Collected"
- **Contact:** Link to support.html or email
- **Effective Date:** April 6, 2026

- [ ] **Step 4: Commit and push the website**

```bash
cd /Volumes/MacLive/Users/larryseyer/JTFNews
git add docs/privacy.html
git commit -m "Add privacy policy page for App Store submission"
git push
```

- [ ] **Step 5: Verify the page is live**

Wait 1-2 minutes for GitHub Pages, then verify: `https://jtfnews.org/privacy.html`

---

### Task 2: Update App Store Metadata File

**Files:**
- Modify: `/Users/larryseyer/jtfnewsapp/JTFNews/metadata/AppStoreMetadata.md`

- [ ] **Step 1: Update the metadata file with complete App Store Connect info**

Update the file to include:

```markdown
## Privacy Policy URL
https://jtfnews.org/privacy.html

## Support URL
https://jtfnews.org/support.html

## Marketing URL
https://jtfnews.org
```

- [ ] **Step 2: Commit**

```bash
cd /Users/larryseyer/jtfnewsapp
git add JTFNews/metadata/AppStoreMetadata.md
git commit -m "APP-027: Update App Store metadata with privacy and support URLs"
```

---

### Task 3: Add macOS App Sandbox Entitlements

**Context:** Mac App Store requires all apps to be sandboxed. The app needs network access (to fetch from jtfnews.org) and outgoing connections. Currently no .entitlements file exists.

**Files:**
- Create: `/Users/larryseyer/jtfnewsapp/JTFNews/JTFNews.entitlements`
- Modify: `/Users/larryseyer/jtfnewsapp/JTFNews.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create the entitlements file**

Create `/Users/larryseyer/jtfnewsapp/JTFNews/JTFNews.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

- `com.apple.security.app-sandbox` — Required for Mac App Store
- `com.apple.security.network.client` — Allows outgoing network requests to jtfnews.org

- [ ] **Step 2: Add entitlements to project.pbxproj**

In the project.pbxproj, add to BOTH Debug and Release build settings for the macOS platform:

```
CODE_SIGN_ENTITLEMENTS = JTFNews/JTFNews.entitlements;
```

This should be added under the `buildSettings` sections that contain the macOS configuration. Since the project uses a single target for both platforms, the entitlements only apply to macOS builds automatically via the sandbox key.

- [ ] **Step 3: Verify macOS build still works with sandbox**

```bash
cd /Users/larryseyer/jtfnewsapp
xcodebuild clean build -project JTFNews.xcodeproj -scheme JTFNews -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add JTFNews/JTFNews.entitlements JTFNews.xcodeproj/project.pbxproj
git commit -m "APP-028: Add macOS App Sandbox entitlements for Mac App Store"
```

---

### Task 4: Add macOS Icon to Asset Catalog

**Context:** The Contents.json only lists the icon for iOS. macOS needs its own entry pointing to the same 1024x1024 PNG.

**Files:**
- Modify: `/Users/larryseyer/jtfnewsapp/JTFNews/Assets.xcassets/AppIcon.appiconset/Contents.json`

- [ ] **Step 1: Update Contents.json to include macOS platform**

Replace the contents with:

```json
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "filename" : "AppIcon.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "AppIcon.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 2: Verify both platforms build**

```bash
cd /Users/larryseyer/jtfnewsapp
xcodebuild build -project JTFNews.xcodeproj -scheme JTFNews -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
xcodebuild build -project JTFNews.xcodeproj -scheme JTFNews -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
```

Expected: Both `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add JTFNews/Assets.xcassets/AppIcon.appiconset/Contents.json
git commit -m "APP-029: Add macOS icon entry to asset catalog"
```

---

### Task 5: Set Export Compliance and Team ID in Build Settings

**Context:** Apple asks about encryption on every upload. Setting `ITSAppUsesNonExemptEncryption = NO` in Info.plist avoids the manual questionnaire each time. Also need to set the Development Team for code signing.

**Files:**
- Modify: `/Users/larryseyer/jtfnewsapp/JTFNews.xcodeproj/project.pbxproj`

- [ ] **Step 1: Add export compliance flag to build settings**

In project.pbxproj, add to BOTH Debug and Release buildSettings:

```
INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;
```

The app only uses HTTPS via URLSession, which is exempt from export compliance requirements.

- [ ] **Step 2: Set DEVELOPMENT_TEAM**

In project.pbxproj, replace the empty DEVELOPMENT_TEAM in BOTH Debug and Release buildSettings:

```
DEVELOPMENT_TEAM = <YOUR_TEAM_ID>;
```

**The developer must provide their Team ID** (from https://developer.apple.com/account > Membership Details).

- [ ] **Step 3: Verify signing works**

```bash
cd /Users/larryseyer/jtfnewsapp
xcodebuild build -project JTFNews.xcodeproj -scheme JTFNews -destination 'platform=macOS' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **` (without CODE_SIGNING_ALLOWED=NO this time)

- [ ] **Step 4: Commit**

```bash
git add JTFNews.xcodeproj/project.pbxproj
git commit -m "APP-030: Set export compliance and development team for App Store"
```

---

### Task 6: Update Privacy Policy URL in App and Metadata

**Context:** The in-app Settings links to jtfnews.org for privacy. Now that we have a dedicated page, update the link. Also update the metadata file.

**Files:**
- Modify: `/Users/larryseyer/jtfnewsapp/JTFNews/metadata/AppStoreMetadata.md`

- [ ] **Step 1: Verify the privacy URL is already correct in metadata**

After Task 2, the metadata should already have `https://jtfnews.org/privacy.html`. Verify and move on.

- [ ] **Step 2: Commit the SettingsView.swift link we added earlier (JTFNews.org link)**

If not already committed:

```bash
git add JTFNews/Views/Settings/SettingsView.swift
git commit -m "APP-031: Add JTFNews.org link to Settings about section"
```

---

### Task 7: Capture App Store Screenshots

**Context:** App Store requires screenshots for specific device sizes. We need:
- **iPhone 6.7"** (iPhone 15 Pro Max / 16 Pro Max) — 1290 x 2796 px
- **iPhone 6.5"** (iPhone 11 Pro Max) — 1242 x 2688 px (optional if 6.7" provided)
- **iPad 12.9"** (iPad Pro 12.9") — 2048 x 2732 px
- **Mac** — at least 1280 x 800 px

Minimum 1 screenshot per size, recommended 3-5 showing: Stories, Digest, Archive.

- [ ] **Step 1: Boot iPhone 16 Pro Max simulator**

```bash
# Find the iPhone 16 Pro Max simulator for iOS 18.x
xcrun simctl list devices available | grep "iPhone 16 Pro Max"
# Boot it
xcrun simctl boot <DEVICE_ID>
open -a Simulator
```

- [ ] **Step 2: Build and install on iPhone simulator**

```bash
cd /Users/larryseyer/jtfnewsapp
xcodebuild build -project JTFNews.xcodeproj -scheme JTFNews \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
xcrun simctl install booted build/Debug-iphonesimulator/JTFNews.app
xcrun simctl launch booted org.jtfnews.app
```

- [ ] **Step 3: Capture iPhone screenshots**

Wait for the app to load data, then capture each tab:

```bash
mkdir -p /Users/larryseyer/jtfnewsapp/screenshots
# Stories tab
xcrun simctl io booted screenshot /Users/larryseyer/jtfnewsapp/screenshots/iphone_stories.png
# Navigate to Digest tab, then:
xcrun simctl io booted screenshot /Users/larryseyer/jtfnewsapp/screenshots/iphone_digest.png
# Navigate to Archive tab, then:
xcrun simctl io booted screenshot /Users/larryseyer/jtfnewsapp/screenshots/iphone_archive.png
```

**Note:** You'll need to manually tap each tab in the simulator before capturing. Alternatively, capture from the Simulator app: File > Screenshot (Cmd+S).

- [ ] **Step 4: Capture iPad screenshots**

```bash
# Boot iPad Pro 12.9-inch simulator
xcrun simctl list devices available | grep "iPad Pro 13"
xcrun simctl boot <DEVICE_ID>
# Build, install, launch, and screenshot same as above
```

- [ ] **Step 5: Capture Mac screenshots**

Run the macOS app and use Cmd+Shift+4 to capture window screenshots of each tab. Save to `/Users/larryseyer/jtfnewsapp/screenshots/`.

- [ ] **Step 6: Verify screenshot dimensions**

```bash
for f in /Users/larryseyer/jtfnewsapp/screenshots/*.png; do
  echo "$f: $(sips -g pixelHeight -g pixelWidth "$f" | grep pixel)"
done
```

---

### Task 8: Build Release Archives

**Context:** App Store submissions require archived builds signed with distribution certificates. Xcode's automatic signing handles this.

- [ ] **Step 1: Clean build folder**

```bash
cd /Users/larryseyer/jtfnewsapp
rm -rf build/
```

- [ ] **Step 2: Archive for iOS (Universal: iPhone + iPad)**

```bash
xcodebuild archive \
  -project JTFNews.xcodeproj \
  -scheme JTFNews \
  -destination 'generic/platform=iOS' \
  -archivePath build/JTFNews-iOS.xcarchive \
  2>&1 | tail -10
```

Expected: `** ARCHIVE SUCCEEDED **`

- [ ] **Step 3: Archive for macOS (Universal: Intel + Apple Silicon)**

```bash
xcodebuild archive \
  -project JTFNews.xcodeproj \
  -scheme JTFNews \
  -destination 'generic/platform=macOS' \
  -archivePath build/JTFNews-macOS.xcarchive \
  2>&1 | tail -10
```

Expected: `** ARCHIVE SUCCEEDED **`

- [ ] **Step 4: Verify archives exist**

```bash
ls -la build/*.xcarchive
```

---

### Task 9: Export and Upload to App Store Connect

**Context:** Archives need to be exported as IPA (iOS) and APP (macOS), then uploaded to App Store Connect.

- [ ] **Step 1: Create iOS export options plist**

Create `/Users/larryseyer/jtfnewsapp/ExportOptions-iOS.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

- [ ] **Step 2: Create macOS export options plist**

Create `/Users/larryseyer/jtfnewsapp/ExportOptions-macOS.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

- [ ] **Step 3: Export and upload iOS archive**

```bash
xcodebuild -exportArchive \
  -archivePath build/JTFNews-iOS.xcarchive \
  -exportOptionsPlist ExportOptions-iOS.plist \
  -exportPath build/export-ios \
  2>&1 | tail -10
```

This will sign, export, and upload the iOS build to App Store Connect.

- [ ] **Step 4: Export and upload macOS archive**

```bash
xcodebuild -exportArchive \
  -archivePath build/JTFNews-macOS.xcarchive \
  -exportOptionsPlist ExportOptions-macOS.plist \
  -exportPath build/export-macos \
  2>&1 | tail -10
```

- [ ] **Step 5: Verify uploads in App Store Connect**

Go to https://appstoreconnect.apple.com > Your App > TestFlight tab. Both builds should appear within 5-15 minutes after upload. They'll show as "Processing" initially.

---

### Task 10: Configure App Store Connect Listing (Manual — In Browser)

**Context:** This must be done manually in the App Store Connect web interface.

- [ ] **Step 1: iOS App Store listing**

Go to App Store Connect > Your App > iOS tab > App Information:

- **Subtitle:** Just the Facts. Verified News.
- **Category:** News
- **Content Rights:** "This app does not contain, show, or access third-party content" — NO (it shows news from jtfnews.org which you own, so select "Yes, I own or have rights")
- **Age Rating:** Fill out the questionnaire — answer "None" to all questions (no violence, profanity, etc.) — result should be 4+

Go to Pricing and Availability:
- **Price:** Free
- **Availability:** All territories (or select specific ones)

Go to App Privacy:
- **Data Types:** Select "None" — the app collects no data

Go to Version Information:
- **Screenshots:** Upload the iPhone and iPad screenshots from Task 7
- **Description:** (Copy from AppStoreMetadata.md)
- **Keywords:** news, facts, verified, unbiased, transparency, source ratings, accuracy, media literacy, fact check, daily digest
- **Support URL:** https://jtfnews.org/support.html
- **Marketing URL:** https://jtfnews.org
- **Privacy Policy URL:** https://jtfnews.org/privacy.html
- **Copyright:** 2026 JTF News
- **Build:** Select the uploaded iOS build

- [ ] **Step 2: macOS App Store listing**

Go to the macOS tab and fill in the same information. Upload Mac screenshots.

- [ ] **Step 3: Submit for Review**

Once both platforms have builds selected and all metadata filled in:
- Click "Add for Review" on each platform
- Click "Submit to App Review"

**Expected timeline:** Apple typically reviews within 24-48 hours. First submissions may take slightly longer.

---

## Post-Submission Checklist

After submitting, verify:
- [ ] Both iOS and macOS builds show "Waiting for Review" status
- [ ] Privacy policy page is accessible at https://jtfnews.org/privacy.html
- [ ] Support page is accessible at https://jtfnews.org/support.html
- [ ] No email from Apple about missing metadata or rejection

## Common First-Submission Rejection Reasons to Avoid

1. **Privacy policy URL not accessible** — Make sure GitHub Pages has deployed
2. **Screenshots don't match app** — Use real screenshots, not mockups
3. **App crashes on launch** — Test the release archive on a real device if possible
4. **Insufficient metadata** — Fill out ALL fields in App Store Connect
5. **Guideline 4.2 (Minimum Functionality)** — The app has three full tabs of content, this shouldn't be an issue
