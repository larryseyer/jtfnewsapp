#!/bin/bash
# both.sh — Clean Release build, install & launch on physical iPhone + iPad Simulator
set -e

SCHEME="JTFNews"
IPAD_SIM="iPad Air 11-inch (M2)"
IPHONE_DEST="platform=iOS,id=00008030-0004299C1410802E"
IPAD_DEST="platform=iOS Simulator,name=${IPAD_SIM}"
APP_BUNDLE="org.jtfnews.app"
BUILD_DIR="$(pwd)/build"

echo "═══════════════════════════════════════════════"
echo "  JTF News — Clean Release Build & Launch"
echo "═══════════════════════════════════════════════"
echo ""

# ── Step 1: Boot iPad Simulator in background ─────────────
echo "▸ Booting ${IPAD_SIM} simulator..."
xcrun simctl boot "${IPAD_SIM}" 2>/dev/null || true
open -a Simulator

# ── Step 2: Clean Release build for iPhone ────────────────
echo ""
echo "▸ Building Release for iPhone..."
xcodebuild \
  -scheme "$SCHEME" \
  -destination "$IPHONE_DEST" \
  -configuration Release \
  clean build \
  2>&1 | tail -5

echo "✓ iPhone build succeeded"

# Install on physical device (copy to /tmp to avoid sandbox restrictions)
DEVICE_UUID=$(xcrun devicectl list devices 2>&1 | grep "iPhone" | awk '{print $3}')
IPHONE_APP="${BUILD_DIR}/Release-iphoneos/JTFNews.app"
if [ -d "$IPHONE_APP" ] && [ -n "$DEVICE_UUID" ]; then
  echo "▸ Installing on iPhone..."
  rm -rf /tmp/JTFNews.app
  cp -R "$IPHONE_APP" /tmp/JTFNews.app
  xcrun devicectl device install app --device "$DEVICE_UUID" /tmp/JTFNews.app 2>&1 | tail -3
  echo "▸ Launching on iPhone..."
  xcrun devicectl device process launch --device "$DEVICE_UUID" "$APP_BUNDLE" 2>&1 | tail -3
  echo "✓ iPhone running"
else
  echo "⚠ iPhone not connected or app not found — skipping install"
fi

# ── Step 3: Clean Release build for iPad Simulator ────────
echo ""
echo "▸ Building Release for iPad Simulator..."
xcodebuild \
  -scheme "$SCHEME" \
  -destination "$IPAD_DEST" \
  -configuration Release \
  clean build \
  2>&1 | tail -5

echo "✓ iPad Simulator build succeeded"

# ── Step 4: Install & launch on iPad Simulator ────────────
echo ""
SIM_APP="${BUILD_DIR}/Release-iphonesimulator/JTFNews.app"
if [ -d "$SIM_APP" ]; then
  echo "▸ Installing on iPad Simulator..."
  xcrun simctl install "${IPAD_SIM}" "$SIM_APP"
  echo "▸ Launching on iPad Simulator..."
  xcrun simctl launch "${IPAD_SIM}" "$APP_BUNDLE"
  echo "✓ iPad Simulator running"
else
  echo "⚠ Simulator .app not found — launch manually from Xcode"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ Done"
echo "═══════════════════════════════════════════════"
