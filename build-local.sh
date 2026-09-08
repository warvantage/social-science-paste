#!/bin/bash
# SPDX-License-Identifier: MPL-2.0
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Social Science Paste"
EXEC_NAME="SocialSciencePaste"
VERSION="${1:-1.0.0}"
DEPLOYMENT_TARGET="11.0"
DIST="$PWD/dist"
APP="$DIST/$APP_NAME.app"
BIN="$APP/Contents/MacOS/$EXEC_NAME"
BUILD_ERR="$DIST/build-arm64.err"
DMG_ROOT="$DIST/dmg-root"
DMG="$DIST/Social-Science-Paste-${VERSION}.dmg"

printf '
Social Science Paste — Apple Silicon build (v%s)

' "$VERSION"
echo "Host: $(sw_vers -productVersion 2>/dev/null || echo unknown) / $(uname -m)"
echo "Target: Apple Silicon (arm64), macOS ${DEPLOYMENT_TARGET}+"

echo "Running architecture self-check…"
bash ./self-check.sh

if ! command -v xcrun >/dev/null 2>&1; then
  echo "Apple Command Line Tools were not found."
  echo "Install them with: xcode-select --install"
  exit 1
fi

SWIFTC=$(xcrun --find swiftc 2>/dev/null || true)
SDK=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)
if [ -z "$SWIFTC" ] || [ -z "$SDK" ]; then
  echo "Swift/macOS SDK not found."
  exit 1
fi

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp Assets/social-science-paste-logo.png "$APP/Contents/Resources/social-science-paste-logo.png"
cp Assets/SocialSciencePaste.icns "$APP/Contents/Resources/SocialSciencePaste.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleGetInfoString Social Science Paste $VERSION — Social Science Paste project" "$APP/Contents/Info.plist"

echo "Building app…"
if ! "$SWIFTC" Sources/SocialSciencePaste/main.swift \
  -o "$BIN" \
  -sdk "$SDK" \
  -target "arm64-apple-macosx$DEPLOYMENT_TARGET" \
  -framework Cocoa \
  -framework ServiceManagement \
  2>"$BUILD_ERR"; then
  cat "$BUILD_ERR"
  exit 1
fi
chmod +x "$BIN"

if ! /usr/bin/file "$BIN" | grep -q 'arm64'; then
  echo "Build check failed: executable is not arm64."
  exit 1
fi

# Ad-hoc signing: this is not Developer ID signing or notarisation.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "Creating DMG…"
mkdir -p "$DMG_ROOT"
cp -R "$APP" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$DMG_ROOT"

echo
echo "Done."
echo "App: $APP"
echo "DMG: $DMG"
