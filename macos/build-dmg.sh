#!/bin/bash
set -e

echo "=============================="
echo "  TypeFlow macOS Build Script"
echo "=============================="
echo ""

# Check we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: This script must be run on macOS."
    echo "You need Xcode installed to build the app."
    exit 1
fi

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "ERROR: Xcode command line tools not found."
    echo "Install with: xcode-select --install"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_NAME="TypeFlow"
DMG_NAME="TypeFlow-1.0.0"

echo "Building ${APP_NAME}..."
echo ""

# Build the app
cd "${SCRIPT_DIR}"
xcodebuild -project TypeFlow.xcodeproj \
    -scheme TypeFlow \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/derived" \
    ONLY_ACTIVE_ARCH=NO \
    clean build

# Find the built app
APP_PATH=$(find "${BUILD_DIR}/derived" -name "TypeFlow.app" -type d | head -1)

if [[ -z "$APP_PATH" ]]; then
    echo "ERROR: Could not find built TypeFlow.app"
    exit 1
fi

echo ""
echo "App built successfully at: ${APP_PATH}"
echo ""

# Create DMG
DMG_DIR="${BUILD_DIR}/dmg"
rm -rf "${DMG_DIR}"
mkdir -p "${DMG_DIR}"

cp -R "${APP_PATH}" "${DMG_DIR}/"
ln -s /Applications "${DMG_DIR}/Applications"

echo "Creating DMG..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov -format UDZO \
    "${BUILD_DIR}/${DMG_NAME}.dmg"

echo ""
echo "=============================="
echo "  Build Complete!"
echo "  DMG: ${BUILD_DIR}/${DMG_NAME}.dmg"
echo "=============================="
