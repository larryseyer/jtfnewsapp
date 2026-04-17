#!/usr/bin/env bash
# capture_screenshots.sh — boot a simulator, install the Release build, launch it.
#
# Usage:
#   ./capture_screenshots.sh setup iphone   # boot iPhone 16 Pro Max + install + launch
#   ./capture_screenshots.sh setup ipad     # boot iPad Pro 13 (M4) + install + launch
#   ./capture_screenshots.sh setup watch    # boot Apple Watch Series 10 46mm + install + launch
#   ./capture_screenshots.sh snap iphone stories   # screenshot booted iPhone -> screenshots/iphone/stories.png
#   ./capture_screenshots.sh snap ipad archive     # same pattern for iPad
#   ./capture_screenshots.sh snap watch list       # same pattern for watch
#
# After `setup`, navigate manually in the simulator, then `snap` each tab with a meaningful label.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

IPHONE_NAME="iPhone 16 Pro Max"
IPAD_NAME="iPad Pro 13-inch (M4)"
WATCH_NAME="Apple Watch Series 10 (46mm)"
BUNDLE_ID="com.larryseyer.jtfnews"
WATCH_BUNDLE_ID="com.larryseyer.jtfnews.watchkitapp"

device_id_for() {
  local name="$1"
  xcrun simctl list devices available | awk -v n="$name" '
    $0 ~ n {
      match($0, /\(([-0-9A-F]+)\)/, a)
      if (a[1]) { print a[1]; exit }
    }'
}

boot_and_focus() {
  local udid="$1"
  local state
  state="$(xcrun simctl list devices | awk -v u="$udid" '$0 ~ u { match($0, /\(([A-Za-z]+)\)[^(]*$/, a); print a[1]; exit }')"
  if [ "$state" != "Booted" ]; then
    xcrun simctl boot "$udid"
  fi
  open -a Simulator
}

build_release_for() {
  local destination="$1"
  echo ">> Building Release for $destination"
  xcodebuild build \
    -project JTFNews.xcodeproj \
    -scheme JTFNews \
    -configuration Release \
    -destination "$destination" \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
}

setup_iphone() {
  local udid; udid="$(device_id_for "$IPHONE_NAME")"
  [ -z "$udid" ] && { echo "No $IPHONE_NAME simulator found."; exit 1; }
  echo ">> iPhone UDID: $udid"
  build_release_for "platform=iOS Simulator,id=$udid"
  boot_and_focus "$udid"
  echo ">> Installing app…"
  xcrun simctl install "$udid" "build/Release-iphonesimulator/JTFNews.app"
  xcrun simctl launch "$udid" "$BUNDLE_ID"
  cat <<EOF

iPhone ready. Navigate to the tab you want, then run:
  ./capture_screenshots.sh snap iphone stories
  ./capture_screenshots.sh snap iphone story_detail
  ./capture_screenshots.sh snap iphone digest
  ./capture_screenshots.sh snap iphone archive
  ./capture_screenshots.sh snap iphone watched
  ./capture_screenshots.sh snap iphone widget     # from home screen after long-pressing a widget
EOF
}

setup_ipad() {
  local udid; udid="$(device_id_for "$IPAD_NAME")"
  [ -z "$udid" ] && { echo "No $IPAD_NAME simulator found."; exit 1; }
  echo ">> iPad UDID: $udid"
  build_release_for "platform=iOS Simulator,id=$udid"
  boot_and_focus "$udid"
  xcrun simctl install "$udid" "build/Release-iphonesimulator/JTFNews.app"
  xcrun simctl launch "$udid" "$BUNDLE_ID"
  cat <<EOF

iPad ready. Snap at minimum:
  ./capture_screenshots.sh snap ipad stories
  ./capture_screenshots.sh snap ipad archive
EOF
}

setup_watch() {
  local udid; udid="$(device_id_for "$WATCH_NAME")"
  [ -z "$udid" ] && { echo "No $WATCH_NAME simulator found."; exit 1; }
  echo ">> Watch UDID: $udid"
  xcodebuild build \
    -project JTFNews.xcodeproj \
    -scheme JTFNews \
    -configuration Release \
    -destination "platform=watchOS Simulator,id=$udid" \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3
  boot_and_focus "$udid"
  local app_path
  app_path="$(find build -type d -name 'JTFNewsWatch.app' -path '*Release-watchsimulator*' 2>/dev/null | head -1)"
  [ -z "$app_path" ] && { echo "Watch app binary not found under build/Release-watchsimulator*. Check scheme includes JTFNewsWatch."; exit 1; }
  xcrun simctl install "$udid" "$app_path"
  xcrun simctl launch "$udid" "$WATCH_BUNDLE_ID"
  cat <<EOF

Watch ready. Snap:
  ./capture_screenshots.sh snap watch list
  ./capture_screenshots.sh snap watch empty
EOF
}

snap() {
  local device="$1"
  local label="$2"
  local udid name
  case "$device" in
    iphone) name="$IPHONE_NAME" ;;
    ipad)   name="$IPAD_NAME" ;;
    watch)  name="$WATCH_NAME" ;;
    *) echo "Unknown device '$device' (use iphone|ipad|watch)"; exit 1 ;;
  esac
  udid="$(device_id_for "$name")"
  [ -z "$udid" ] && { echo "No $name simulator found."; exit 1; }
  mkdir -p "screenshots/$device"
  local out="screenshots/$device/${label}.png"
  xcrun simctl io "$udid" screenshot "$out"
  echo ">> Saved: $out"
  sips -g pixelWidth -g pixelHeight "$out" | sed 's/^/   /'
}

cmd="${1:-}"
case "$cmd" in
  setup)
    case "${2:-}" in
      iphone) setup_iphone ;;
      ipad)   setup_ipad ;;
      watch)  setup_watch ;;
      *) echo "Usage: $0 setup {iphone|ipad|watch}"; exit 1 ;;
    esac
    ;;
  snap)
    [ -z "${2:-}" ] || [ -z "${3:-}" ] && { echo "Usage: $0 snap {iphone|ipad|watch} <label>"; exit 1; }
    snap "$2" "$3"
    ;;
  mac)
    cat <<EOF
macOS screenshots are captured from the running .app — not a simulator.

1. Launch the macOS build:
     open "build/JTFNews-macOS.xcarchive/Products/Applications/JTFNews.app"
2. Resize the window to roughly 1280x800 or 1440x900.
3. Cmd+Shift+4, then Space, then click the JTFNews window to capture it.
4. Save captures into: screenshots/mac/<label>.png
   Recommended labels: stories, digest, archive, watched
EOF
    ;;
  *)
    cat <<EOF
capture_screenshots.sh — App Store screenshot helper

Commands:
  $0 setup iphone         Boot iPhone 16 Pro Max, install, launch
  $0 setup ipad           Boot iPad Pro 13 (M4), install, launch
  $0 setup watch          Boot Apple Watch Series 10, install, launch
  $0 mac                  Print Mac capture instructions (no automation)
  $0 snap iphone <label>  Capture booted iPhone screen to screenshots/iphone/<label>.png
  $0 snap ipad   <label>  Capture booted iPad screen
  $0 snap watch  <label>  Capture booted watch screen

Recommended capture list per AppStoreMetadata.md:
  iPhone: stories, story_detail, digest, archive, watched, widget
  iPad:   stories, archive
  Watch:  list, empty
  Mac:    stories, digest, archive, watched  (use '$0 mac' for instructions)
EOF
    ;;
esac
