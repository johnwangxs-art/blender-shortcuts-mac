#!/bin/bash
set -euo pipefail

# ── Config ──────────────────────────────────────────────────────
APP_NAME="BlenderShortcuts"
BUNDLE_ID="com.blender.shortcuts-lookup"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SRC_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

SWIFT_SRC="${SRC_DIR}/${APP_NAME}/AppDelegate.swift"
PLIST_SRC="${SRC_DIR}/${APP_NAME}/Info.plist"
HTML_SRC="${SRC_DIR}/${APP_NAME}/Resources/blender_shortcuts.html"

# ── Clean ───────────────────────────────────────────────────────
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# ── Compile ──────────────────────────────────────────────────────
echo "🔨  Compiling Swift source..."
swiftc \
    -o "${BUILD_DIR}/${APP_NAME}" \
    "${SWIFT_SRC}" \
    -framework Cocoa \
    -framework WebKit \
    -target arm64-apple-macosx13.0 \
    -swift-version 6

echo "✅  Compilation successful"

# ── Build .app bundle ───────────────────────────────────────────
echo "📦  Building app bundle..."

mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy Info.plist
cp "${PLIST_SRC}" "${APP_BUNDLE}/Contents/Info.plist"

# Copy HTML resource
cp "${HTML_SRC}" "${APP_BUNDLE}/Contents/Resources/blender_shortcuts.html"

echo "✅  App bundle created: ${APP_BUNDLE}"
echo ""
echo "📂  Bundle structure:"
find "${APP_BUNDLE}" -type f | sed "s|${BUILD_DIR}/||"
echo ""
APP_SIZE=$(du -sh "${APP_BUNDLE}" | cut -f1)
echo "💾  App size: ${APP_SIZE}"
echo ""
echo "🚀  To run: open \"${APP_BUNDLE}\""
echo "   or:      \"${APP_BUNDLE}/Contents/MacOS/${APP_NAME}\""
