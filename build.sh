#!/bin/bash
set -e

APP_NAME="FocusFocus"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BUILD_CACHE="build/ModuleCache"

echo "🔨 Building ${APP_NAME}..."

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
mkdir -p "$BUILD_CACHE"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/"

# Copy AppIcon if present
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$RESOURCES_DIR/"
fi

# Compile Swift files as a universal binary (arm64 + x86_64), pinned to the
# minimum deployment target declared in Info.plist. Without an explicit
# -target, swiftc defaults to the host machine's SDK version, which silently
# raises the app's real minimum OS requirement above what Info.plist claims.
DEPLOYMENT_TARGET="12.0"
swiftc -module-cache-path "$BUILD_CACHE" -target "arm64-apple-macos${DEPLOYMENT_TARGET}" src/*.swift -o "$MACOS_DIR/${APP_NAME}-arm64"
swiftc -module-cache-path "$BUILD_CACHE" -target "x86_64-apple-macos${DEPLOYMENT_TARGET}" src/*.swift -o "$MACOS_DIR/${APP_NAME}-x86_64"
lipo -create "$MACOS_DIR/${APP_NAME}-arm64" "$MACOS_DIR/${APP_NAME}-x86_64" -output "$MACOS_DIR/$APP_NAME"
rm "$MACOS_DIR/${APP_NAME}-arm64" "$MACOS_DIR/${APP_NAME}-x86_64"

# Ad-hoc sign with entitlements for local testing
if [ -f "FocusFocus.entitlements" ]; then
    codesign --force --sign - --entitlements FocusFocus.entitlements "$APP_DIR" 2>/dev/null || true
fi

echo "✅ Successfully built ${APP_DIR}"
