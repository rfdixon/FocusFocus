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

# Compile Swift files
swiftc -module-cache-path "$BUILD_CACHE" src/*.swift -o "$MACOS_DIR/$APP_NAME"

# Ad-hoc sign with entitlements for local testing
if [ -f "FocusFocus.entitlements" ]; then
    codesign --force --sign - --entitlements FocusFocus.entitlements "$APP_DIR" 2>/dev/null || true
fi

echo "✅ Successfully built ${APP_DIR}"
