#!/bin/bash
# both.sh — Clean Release build, install & launch on physical iPhone + iPad 18.1 Simulator.
#
# Deterministic deploys only: every target is pinned by UDID so ambiguous-name lookups
# (there are 6 sims called "iPad (10th generation)") can't select the wrong device.
# Errors surface loudly (pipefail) instead of being swallowed by `| tail`.

set -euo pipefail

SCHEME="JTFNews"
APP_BUNDLE="com.larryseyer.jtfnews"
BUILD_DIR="$(pwd)/build"
LOG_DIR="$(pwd)/build-logs"
mkdir -p "$LOG_DIR"

# ── Physical iPhone 11 Pro Max ─────────────────────────────
# xcodebuild uses the ECID; devicectl uses the separate CoreDevice UUID.
IPHONE_ECID="00008030-0004299C1410802E"
IPHONE_DEST="platform=iOS,id=${IPHONE_ECID}"
IPHONE_UUID_FALLBACK="857137D4-8FD7-5077-8DC4-FB68165978DD"

# ── iPad (10th generation) · iOS 18.1 simulator ────────────
# Pinned by UDID because the name alone matches 6 sims across 5 runtimes.
IPAD_UDID="86F64729-D28D-44F7-BEB9-EF34AA7B7F28"
IPAD_NAME="iPad (10th generation) · iOS 18.1"
IPAD_DEST="platform=iOS Simulator,id=${IPAD_UDID}"

echo "═══════════════════════════════════════════════"
echo "  JTF News — Clean Release Build & Launch"
echo "═══════════════════════════════════════════════"
echo ""

# ── Step 1: Boot iPad Simulator and wait for it to be ready ─
echo "▸ Booting ${IPAD_NAME}…"
xcrun simctl boot "$IPAD_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$IPAD_UDID" -b >/dev/null
open -a Simulator

# ── Step 2: Resolve iPhone CoreDevice UUID (regex, not field index) ─
IPHONE_UUID="$(xcrun devicectl list devices 2>/dev/null \
  | grep "iPhone 11 Pro Max" \
  | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
  | head -1 || true)"
if [ -z "$IPHONE_UUID" ]; then
  echo "⚠ iPhone 11 Pro Max not detected via devicectl — falling back to known UUID"
  IPHONE_UUID="$IPHONE_UUID_FALLBACK"
fi
echo "▸ iPhone CoreDevice UUID: $IPHONE_UUID"

# ── Step 3: Clean Release build for iPhone ─────────────────
echo ""
echo "▸ Building Release for iPhone (log: $LOG_DIR/iphone.log)…"
set +e
xcodebuild \
  -scheme "$SCHEME" \
  -destination "$IPHONE_DEST" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  clean build \
  > "$LOG_DIR/iphone.log" 2>&1
IPHONE_BUILD_RC=$?
set -e
if [ $IPHONE_BUILD_RC -ne 0 ]; then
  echo "✗ iPhone build FAILED — last 40 log lines:"
  tail -40 "$LOG_DIR/iphone.log"
  exit $IPHONE_BUILD_RC
fi
echo "✓ iPhone build succeeded"

# ── Step 4: Uninstall old copy, install, launch on iPhone ──
IPHONE_APP="${BUILD_DIR}/Build/Products/Release-iphoneos/JTFNews.app"
if [ ! -d "$IPHONE_APP" ]; then
  # Back-compat path if SYMROOT override drops it here instead.
  IPHONE_APP="${BUILD_DIR}/Release-iphoneos/JTFNews.app"
fi
if [ -d "$IPHONE_APP" ]; then
  echo "▸ Uninstalling existing iPhone copy (if present)…"
  xcrun devicectl device process terminate --device "$IPHONE_UUID" --bundle-identifier "$APP_BUNDLE" >/dev/null 2>&1 || true
  xcrun devicectl device uninstall app --device "$IPHONE_UUID" "$APP_BUNDLE" >/dev/null 2>&1 || true

  echo "▸ Installing on iPhone…"
  # Copy out of repo first to sidestep container-sandbox reads on some macOS builds.
  rm -rf /tmp/JTFNews.app
  cp -R "$IPHONE_APP" /tmp/JTFNews.app
  xcrun devicectl device install app --device "$IPHONE_UUID" /tmp/JTFNews.app

  echo "▸ Launching on iPhone…"
  xcrun devicectl device process launch --device "$IPHONE_UUID" "$APP_BUNDLE"
  echo "✓ iPhone running"
else
  echo "⚠ iPhone .app not found at expected path — skipping install"
fi

# ── Step 5: Clean Release build for iPad Simulator ─────────
echo ""
echo "▸ Building Release for iPad Simulator (log: $LOG_DIR/ipad.log)…"
set +e
xcodebuild \
  -scheme "$SCHEME" \
  -destination "$IPAD_DEST" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  clean build \
  > "$LOG_DIR/ipad.log" 2>&1
IPAD_BUILD_RC=$?
set -e
if [ $IPAD_BUILD_RC -ne 0 ]; then
  echo "✗ iPad Simulator build FAILED — last 40 log lines:"
  tail -40 "$LOG_DIR/ipad.log"
  exit $IPAD_BUILD_RC
fi
echo "✓ iPad Simulator build succeeded"

# ── Step 6: Uninstall, install, launch on iPad Simulator ───
SIM_APP="${BUILD_DIR}/Build/Products/Release-iphonesimulator/JTFNews.app"
if [ ! -d "$SIM_APP" ]; then
  SIM_APP="${BUILD_DIR}/Release-iphonesimulator/JTFNews.app"
fi
if [ -d "$SIM_APP" ]; then
  echo "▸ Uninstalling existing Simulator copy (if present)…"
  xcrun simctl terminate "$IPAD_UDID" "$APP_BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$IPAD_UDID" "$APP_BUNDLE" >/dev/null 2>&1 || true

  echo "▸ Installing on iPad Simulator…"
  xcrun simctl install "$IPAD_UDID" "$SIM_APP"

  echo "▸ Launching on iPad Simulator…"
  xcrun simctl launch "$IPAD_UDID" "$APP_BUNDLE" >/dev/null
  echo "✓ iPad Simulator running"
else
  echo "⚠ Simulator .app not found at $SIM_APP — launch manually from Xcode"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ Done"
echo "═══════════════════════════════════════════════"
