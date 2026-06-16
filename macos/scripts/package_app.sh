#!/usr/bin/env bash
set -euo pipefail

APP_NAME="IBKR Analytics Studio"
EXECUTABLE_NAME="IBKRAnalyticsStudioMac"
BUNDLE_ID="com.g061206.ibkr-analytics-studio"
APP_VERSION="${APP_VERSION:-2.1.8}"

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MACOS_DIR="$ROOT_DIR/macos"
WEB_DIR="$ROOT_DIR/web"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_BIN_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

if [[ ! -f "$WEB_DIR/index.html" ]]; then
  echo "Missing web bundle at $WEB_DIR" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_BIN_DIR" "$RESOURCES_DIR"

cd "$MACOS_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/$EXECUTABLE_NAME"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Missing built executable at $BIN_PATH" >&2
  exit 1
fi

cp "$BIN_PATH" "$MACOS_BIN_DIR/$EXECUTABLE_NAME"
ditto "$WEB_DIR" "$RESOURCES_DIR/web"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_VERSION</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.finance</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS_DIR/Info.plist"
SELF_TEST_LOG="$DIST_DIR/self-test.log"
SELF_TEST_STATUS="$DIST_DIR/self-test.status"
set +e
IBKR_SELF_TEST=1 IBKR_WEB_ROOT="$RESOURCES_DIR/web" "$MACOS_BIN_DIR/$EXECUTABLE_NAME" > "$SELF_TEST_LOG" 2>&1
SELF_TEST_EXIT_CODE=$?
set -e
cat "$SELF_TEST_LOG"
echo "$SELF_TEST_EXIT_CODE" > "$SELF_TEST_STATUS"

ARCH_NAME="$(uname -m)"
ZIP_PATH="$DIST_DIR/IBKRAnalyticsStudio-${APP_VERSION}-macos-${ARCH_NAME}-unsigned.zip"
DMG_PATH="$DIST_DIR/IBKRAnalyticsStudio-${APP_VERSION}-macos-${ARCH_NAME}-unsigned.dmg"

cd "$DIST_DIR"
ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_NAME.app" -ov -format UDZO "$DMG_PATH"

echo "Created:"
echo "$ZIP_PATH"
echo "$DMG_PATH"
