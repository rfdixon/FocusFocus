#!/bin/bash
set -e

APP_NAME="FocusFocus"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/"

# Compile Swift files
swiftc src/*.swift -o "$MACOS_DIR/$APP_NAME"

# Reset Accessibility permissions so the new binary prompts for them again
tccutil reset Accessibility com.robertdixon.FocusFocus || true

echo "Successfully built $APP_NAME.app"
