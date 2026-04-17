# Submit to Apple — JTF News 1.0

Step-by-step guide for submitting JTF News to the iOS App Store and Mac App Store.

Last verified: 2026-04-17
Plan source: `/Users/larryseyer/.claude/plans/where-are-we-with-curried-pearl.md`

---

## Current State (already done)

Everything on the code side is complete:

- **Archives built and verified** — both return `** ARCHIVE SUCCEEDED **` with zero warnings.
  - `build/JTFNews-iOS.xcarchive` — `com.larryseyer.jtfnews` 1.0 build 1, widget embedded
  - `build/JTFNews-macOS.xcarchive` — same bundle ID, news category applied
- **Signing** — automatic, team `RR5DY39W4Q`, dev cert `Apple Development: Larry Seyer (63S4HUDY4S)`, provisioning profile auto-issued
- **Export compliance** — `ITSAppUsesNonExemptEncryption = NO` in all six build configs (main + widget + watch × Debug + Release)
- **Mac App Store category** — `LSApplicationCategoryType = public.app-category.news`
- **Privacy URLs** — `https://jtfnews.org/privacy.html` and `https://jtfnews.org/support.html` both return HTTP 200
- **App metadata** — `JTFNews/metadata/AppStoreMetadata.md` has all copy (description, keywords, what's new, subtitle, promotional text)
- **Privacy label posture** — zero third-party SDKs, zero tracking → declare **Data Not Collected** on every category
- **Export configs** — `ExportOptions-iOS.plist` + `ExportOptions-macOS.plist` pre-wired for `app-store-connect` upload with `uploadSymbols=true`, `manageAppVersionAndBuildNumber=false`
- **Screenshot helper** — `./capture_screenshots.sh` boots sims, installs Release builds, launches, and snaps labeled captures

---

## Distribution Model — One Record, Two Uploads

You file a **single** App Store Connect record for `com.larryseyer.jtfnews` with **both iOS and macOS platforms checked**. Then:

| Archive you upload | Surfaces it covers |
|---|---|
| `JTFNews-iOS.xcarchive` | iPhone App Store, iPad App Store, Apple Watch App Store, iOS widgets |
| `JTFNews-macOS.xcarchive` | Mac App Store, Mac widgets |

Watch and Widgets do **not** get their own submissions — they ride embedded inside their parent archive.

---

## Step 1 — Verify / Create the App Store Connect record

**Do this first.** If you skip it, `xcodebuild -exportArchive` fails with "No matching apps found in App Store Connect".

1. Log in to https://appstoreconnect.apple.com
2. Click **My Apps**
3. If `JTF News` appears under `com.larryseyer.jtfnews` → continue to Step 2.
4. If not, create it:
   - Click **+ → New App**
   - **Platforms:** check **both iOS and macOS** (critical — this is what makes one record serve both uploads)
   - **Name:** `JTF News`
   - **Primary Language:** English (U.S.)
   - **Bundle ID dropdown:** select `com.larryseyer.jtfnews` (auto-registered from archive; if missing, the first upload will register it)
   - **SKU:** `jtfnews-app`
   - **User Access:** Full Access
   - Click **Create**

---

## Step 2 — Capture screenshots

Required sizes (Apple 2026 spec):
- **iPhone 6.9"** (iPhone 16 Pro Max, 1320×2868) — **required**
- **iPad 13"** (iPad Pro M4, 2064×2752) — **required for iPad listing**
- **Mac** — minimum 1280×800, prefer 1440×900
- **Apple Watch** — 410×502 (Series 10/SE 2nd gen)

Capture at least one screenshot per tab per device. Apple recommends 3–5 per device.

### iPhone
```bash
cd /Users/larryseyer/jtfnewsapp
./capture_screenshots.sh setup iphone
```

Simulator boots, Release build installs and launches. Navigate to each view in the Simulator, then from this terminal:
```bash
./capture_screenshots.sh snap iphone stories
./capture_screenshots.sh snap iphone story_detail
./capture_screenshots.sh snap iphone digest
./capture_screenshots.sh snap iphone archive
./capture_screenshots.sh snap iphone watched
./capture_screenshots.sh snap iphone widget   # long-press home screen, add widget, then snap
```

Captures land in `screenshots/iphone/<label>.png` and each command prints the resolution so you can confirm it matches Apple's requirement.

### iPad
```bash
./capture_screenshots.sh setup ipad
./capture_screenshots.sh snap ipad stories
./capture_screenshots.sh snap ipad archive
```

### Apple Watch
```bash
./capture_screenshots.sh setup watch
./capture_screenshots.sh snap watch list
./capture_screenshots.sh snap watch empty
```

### Mac
```bash
./capture_screenshots.sh mac   # prints the manual Cmd+Shift+4 instructions
```

Specifically:
1. `open build/JTFNews-macOS.xcarchive/Products/Applications/JTFNews.app`
2. Resize window to ~1440×900
3. `Cmd+Shift+4`, then Space, then click the JTFNews window
4. Save captures to `screenshots/mac/` with labels: `stories`, `digest`, `archive`, `watched`

### Verify dimensions before upload
```bash
for f in screenshots/*/*.png; do
  echo -n "$f: "
  sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {printf "%s ", $2} END{print ""}'
done
```

---

## Step 3 — Export + upload archives

Only after Step 1 is done (ASC record exists). These commands sign for distribution, export an IPA/PKG, **and** upload to App Store Connect in one shot.

### iOS upload
```bash
cd /Users/larryseyer/jtfnewsapp
xcodebuild -exportArchive \
  -archivePath build/JTFNews-iOS.xcarchive \
  -exportOptionsPlist ExportOptions-iOS.plist \
  -exportPath build/export-ios
```

### macOS upload
```bash
xcodebuild -exportArchive \
  -archivePath build/JTFNews-macOS.xcarchive \
  -exportOptionsPlist ExportOptions-macOS.plist \
  -exportPath build/export-macos
```

Each upload takes 2–5 minutes. Both builds appear in **App Store Connect → TestFlight** within 5–15 min of upload, initially as "Processing".

### If you ever need to rebuild the archives
```bash
rm -rf build/
xcodebuild archive \
  -project JTFNews.xcodeproj \
  -scheme JTFNews \
  -destination 'generic/platform=iOS' \
  -archivePath build/JTFNews-iOS.xcarchive \
  -allowProvisioningUpdates

xcodebuild archive \
  -project JTFNews.xcodeproj \
  -scheme JTFNews \
  -destination 'generic/platform=macOS' \
  -archivePath build/JTFNews-macOS.xcarchive \
  -allowProvisioningUpdates
```

---

## Step 4 — Fill the App Store Connect listing

Your single record now has two tabs on the left rail: **iOS App** and **macOS App**. Each needs its own listing filled in. Most fields can be identical across both tabs; a few (like screenshots) are platform-specific.

Copy values from `JTFNews/metadata/AppStoreMetadata.md`.

### Per-tab fields (fill in on both iOS tab and macOS tab)

| Field | Value |
|---|---|
| Subtitle | `Just the Facts. Verified News.` |
| Promotional Text | `Verified facts from 22 trusted sources. No ads, no tracking, no opinions — just the facts.` |
| Description | Full text from `AppStoreMetadata.md` (multi-paragraph) |
| Keywords | `news, facts, verified, unbiased, transparency, source ratings, accuracy, media literacy, fact check, daily digest` |
| Support URL | `https://jtfnews.org/support.html` |
| Marketing URL | `https://jtfnews.org` |
| Privacy Policy URL | `https://jtfnews.org/privacy.html` |
| Copyright | `© 2026 JTF News` |
| Category (Primary) | News |
| Age Rating | Answer "None" to all questions → result 4+ |
| Content Rights | Yes, I own or have rights |
| Build | Select the uploaded build |

### Platform-specific fields

**iOS tab:**
- **Screenshots:** upload from `screenshots/iphone/` and `screenshots/ipad/`
- **Apple Watch section:** upload from `screenshots/watch/` (optional but recommended since you ship a watch app)

**macOS tab:**
- **Screenshots:** upload from `screenshots/mac/`

### Pricing and Availability (global setting, both platforms)
- **Price:** Free
- **Availability:** All territories (recommended for 1.0)

### App Privacy (global setting, both platforms)
- **Data Collection:** Click "Get Started" → choose **"No, we do not collect data from this app"**
- This produces the **Data Not Collected** label

---

## Step 5 — Submit for review

1. On the **iOS tab**: click **Add for Review** (top right, blue button)
2. Fill the Export Compliance question: **No** (we've already declared `ITSAppUsesNonExemptEncryption=NO` in the binary, so this is a formality)
3. Click **Submit to App Review**
4. Repeat on the **macOS tab**: **Add for Review** → **Submit to App Review**

**Expected timeline:**
- Automated checks: ~1 hour
- Human review (iOS): typically 24–48 hours for first submission
- Human review (macOS): typically 24–72 hours for first submission

Apple reviews them **independently**. iOS usually clears first.

---

## Post-submission checklist

- [ ] Both platforms show **"Waiting for Review"** status in App Store Connect
- [ ] `https://jtfnews.org/privacy.html` still returns HTTP 200 (Apple's crawler will check)
- [ ] `https://jtfnews.org/support.html` still returns HTTP 200
- [ ] No email from Apple about missing metadata or binary issues

If you get rejected, the email explains why. The most common first-submission rejection reasons to avoid:

1. **Privacy policy URL not accessible** — GitHub Pages cache; force-refresh
2. **Screenshots show features not in app** — the screenshots must match what the reviewer can tap
3. **Metadata mismatch** — description promises feature X, app doesn't have it
4. **Guideline 5.1.1 — data collection** — We declared "Data Not Collected" so this should be clean; if Apple flags it, re-verify no analytics SDK snuck in via a dependency

---

## Open items that won't block submission

These were noted during prep but are not blockers:

1. **Server-side patches** (`docs/server_patches/APP-001, APP-019–023`) — apply on the Intel Mac at your own cadence. The iOS app already has client-side resilience (APP-002–005 guards).
2. **Team `NM84277DEZ` ghost** — the bundle ID was migrated to `com.larryseyer.jtfnews` to sidestep this. The dry-run archive on 2026-04-17 confirmed automatic provisioning works cleanly under `RR5DY39W4Q`. No action needed unless a future archive fails.
3. **Developer ID / notarization** (`docs/superpowers/continue-macos-dev-id-signing.md`) — orthogonal channel. Only relevant if you later want to ship the Mac app outside the store.

---

## Files this workflow relies on

| File | Purpose |
|---|---|
| `ExportOptions-iOS.plist` | `xcodebuild -exportArchive` upload config for iOS |
| `ExportOptions-macOS.plist` | Same for macOS |
| `capture_screenshots.sh` | Helper for boot+install+launch+snap |
| `JTFNews/metadata/AppStoreMetadata.md` | Canonical copy for listing fields |
| `build/JTFNews-iOS.xcarchive` | Signed iOS archive (regenerate if versions change) |
| `build/JTFNews-macOS.xcarchive` | Signed macOS archive |
| `screenshots/{iphone,ipad,watch,mac}/` | Per-device captures (empty until Step 2) |
