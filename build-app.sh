#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="GhDashboard"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$VERSION}"
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"

echo "Building release binary..."
cd "$SCRIPT_DIR"
swift build -c release --product GhDashboard

echo "Assembling $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

ICON_SRC="$SCRIPT_DIR/Sources/GhDashboard/Resources/AppIcon.icns"
if [[ -f "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

bash "$SCRIPT_DIR/scripts/render-info-plist.sh" \
  "$APP_BUNDLE/Contents/Info.plist" \
  "$VERSION" \
  "$BUILD_NUMBER"

# Ad-hoc sign for local dev only. Distributed builds need Developer ID + notarization
# (see README “Gatekeeper and code signing”).
codesign --force --sign - "$APP_BUNDLE"

echo ""
echo "Done: $APP_BUNDLE"
echo ""
echo "To install:  cp -r $APP_NAME.app /Applications/"
echo "To run:      open $APP_NAME.app"
