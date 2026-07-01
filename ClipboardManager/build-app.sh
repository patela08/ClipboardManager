#!/bin/bash
# Builds ClipboardManager.app bundle for macOS
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_DIR="$SCRIPT_DIR/.build/ClipboardManager.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building ClipboardManager (release)..."
swift build -c release --package-path "$SCRIPT_DIR"

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/ClipboardManager" "$MACOS_DIR/ClipboardManager"

# Copy Info.plist
cp "$SCRIPT_DIR/Sources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy app icon
if [ -f "$SCRIPT_DIR/Sources/Resources/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/Sources/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "✅ Built: $APP_DIR"
echo ""
echo "To run:"
echo "  open $APP_DIR"
echo ""
echo "To install to Applications:"
echo "  cp -r $APP_DIR /Applications/"
