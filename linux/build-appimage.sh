#!/usr/bin/env bash
# TypeFlow AppImage Builder
#
# Creates a self-contained AppImage distributable of TypeFlow.
# Bundles Python, GTK4 dependencies, and the app into a portable binary.
#
# Usage:
#   chmod +x build-appimage.sh
#   ./build-appimage.sh
#
# Output: TypeFlow-1.0.0-x86_64.AppImage (in current directory)
#
# Requirements (host):
#   - Python 3.10+
#   - python3-gi, gir1.2-gtk-4.0, gir1.2-adw-1
#   - xdotool OR ydotool
#   - wget or curl
#   - FUSE (for running AppImages)
#
# Note: AppImage packaging GTK4 + libadwaita is complex because these
# libraries must match the system's GTK theme engine. This script uses
# a Python-bundled approach where we rely on the host GTK but bundle
# the Python app and pure-Python dependencies.

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────

APP_NAME="TypeFlow"
APP_ID="com.typeflow.app"
APP_VERSION="1.0.0"
ARCH="x86_64"
OUTPUT_NAME="${APP_NAME}-${APP_VERSION}-${ARCH}.AppImage"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
APPDIR="${BUILD_DIR}/AppDir"
APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
APPIMAGETOOL="${BUILD_DIR}/appimagetool"

# Python version to embed
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PYTHON_BIN=$(which python3)

# ─── Colors ──────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Pre-flight Checks ───────────────────────────────────────────────────────

preflight_checks() {
    log_info "Running pre-flight checks..."

    # Python
    if ! command -v python3 &>/dev/null; then
        log_error "python3 not found."
        exit 1
    fi
    log_success "Python $PYTHON_VERSION found at $PYTHON_BIN"

    # PyGObject
    if ! python3 -c "import gi; gi.require_version('Gtk','4.0'); from gi.repository import Gtk" 2>/dev/null; then
        log_error "PyGObject with GTK4 not found."
        log_error "Install: sudo apt install python3-gi gir1.2-gtk-4.0 gir1.2-adw-1"
        exit 1
    fi
    log_success "PyGObject (GTK4) found"

    # Adwaita
    if ! python3 -c "import gi; gi.require_version('Adw','1'); from gi.repository import Adw" 2>/dev/null; then
        log_warn "libadwaita not found. App will fall back to plain GTK4 styling."
        log_warn "Install: sudo apt install gir1.2-adw-1"
    else
        log_success "libadwaita found"
    fi

    # pip / venv
    if ! python3 -m pip --version &>/dev/null; then
        log_error "pip not found. Install python3-pip."
        exit 1
    fi

    # wget or curl
    if ! command -v wget &>/dev/null && ! command -v curl &>/dev/null; then
        log_error "Neither wget nor curl found. Install one to download appimagetool."
        exit 1
    fi
}

# ─── Download appimagetool ───────────────────────────────────────────────────

download_appimagetool() {
    if [ -f "$APPIMAGETOOL" ] && [ -x "$APPIMAGETOOL" ]; then
        log_success "appimagetool already present at $APPIMAGETOOL"
        return 0
    fi

    log_info "Downloading appimagetool..."
    mkdir -p "$BUILD_DIR"

    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
    else
        curl -L --progress-bar -o "$APPIMAGETOOL" "$APPIMAGETOOL_URL"
    fi

    chmod +x "$APPIMAGETOOL"
    log_success "appimagetool downloaded"

    # Check if FUSE is available for running the tool
    if ! "$APPIMAGETOOL" --help &>/dev/null 2>&1; then
        log_warn "appimagetool may require FUSE. Trying --appimage-extract-and-run..."
        # Set env to run without FUSE
        export APPIMAGE_EXTRACT_AND_RUN=1
    fi
}

# ─── Create AppDir Structure ─────────────────────────────────────────────────

create_appdir() {
    log_info "Creating AppDir structure at $APPDIR..."

    # Clean previous build
    rm -rf "$APPDIR"

    # Create directory tree
    mkdir -p "$APPDIR/usr/bin"
    mkdir -p "$APPDIR/usr/lib/typeflow"
    mkdir -p "$APPDIR/usr/share/applications"
    mkdir -p "$APPDIR/usr/share/icons/hicolor/scalable/apps"
    mkdir -p "$APPDIR/usr/share/metainfo"
    mkdir -p "$APPDIR/usr/share/typeflow"

    log_success "AppDir directories created"
}

# ─── Bundle Python Application ───────────────────────────────────────────────

bundle_python_app() {
    log_info "Bundling Python application..."

    # Copy the typeflow package
    cp -r "$SCRIPT_DIR/typeflow" "$APPDIR/usr/lib/typeflow/"
    log_success "typeflow package copied"

    # Create a Python virtual environment inside AppDir for dependencies
    VENV_DIR="$APPDIR/usr/lib/typeflow/venv"
    python3 -m venv --system-site-packages "$VENV_DIR"

    # Install pure-Python dependencies into the venv
    "$VENV_DIR/bin/pip" install --quiet --upgrade pip
    "$VENV_DIR/bin/pip" install --quiet pynput
    log_success "Python dependencies installed in venv"

    # Create the main launcher script
    cat > "$APPDIR/usr/bin/typeflow" << 'LAUNCHER_EOF'
#!/usr/bin/env bash
# TypeFlow AppImage launcher (runs from within AppDir)

APPDIR="$(dirname "$(dirname "$(readlink -f "$0")")")"
TYPEFLOW_LIB="$APPDIR/usr/lib/typeflow"
VENV_PYTHON="$TYPEFLOW_LIB/venv/bin/python3"

# Use venv Python if available, else system Python
if [ -f "$VENV_PYTHON" ]; then
    PYTHON="$VENV_PYTHON"
else
    PYTHON="python3"
fi

# Add app to Python path
export PYTHONPATH="$TYPEFLOW_LIB:${PYTHONPATH:-}"

exec "$PYTHON" -m typeflow "$@"
LAUNCHER_EOF

    chmod +x "$APPDIR/usr/bin/typeflow"
    log_success "Launcher script created"
}

# ─── Install Desktop Integration Files ───────────────────────────────────────

install_data_files() {
    log_info "Installing desktop integration files..."

    # Desktop entry
    cp "$SCRIPT_DIR/data/${APP_ID}.desktop" "$APPDIR/usr/share/applications/"

    # Icon (SVG)
    cp "$SCRIPT_DIR/data/icons/${APP_ID}.svg" \
       "$APPDIR/usr/share/icons/hicolor/scalable/apps/"

    # Also place icon and desktop file at AppDir root (required by AppImage spec)
    cp "$SCRIPT_DIR/data/icons/${APP_ID}.svg" "$APPDIR/${APP_ID}.svg"
    cp "$SCRIPT_DIR/data/${APP_ID}.desktop" "$APPDIR/"

    # AppStream metainfo
    cp "$SCRIPT_DIR/data/${APP_ID}.metainfo.xml" "$APPDIR/usr/share/metainfo/"

    log_success "Data files installed"
}

# ─── Create AppRun ───────────────────────────────────────────────────────────

create_apprun() {
    log_info "Creating AppRun..."

    cat > "$APPDIR/AppRun" << 'APPRUN_EOF'
#!/usr/bin/env bash
# TypeFlow AppRun - Entry point for AppImage

# AppDir is set by the AppImage runtime
APPDIR="${APPDIR:-$(dirname "$(readlink -f "$0")")"}"

export PATH="$APPDIR/usr/bin:$PATH"

# Let GTK find its schemas and themes from the host system
# (GTK4 must come from the host for theming to work correctly)
export XDG_DATA_DIRS="${APPDIR}/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

exec "$APPDIR/usr/bin/typeflow" "$@"
APPRUN_EOF

    chmod +x "$APPDIR/AppRun"
    log_success "AppRun created"
}

# ─── Build AppImage ──────────────────────────────────────────────────────────

build_appimage() {
    log_info "Building AppImage..."

    OUTPUT_PATH="${SCRIPT_DIR}/${OUTPUT_NAME}"

    # Run appimagetool
    ARCH="$ARCH" "$APPIMAGETOOL" \
        ${APPIMAGE_EXTRACT_AND_RUN:+--appimage-extract-and-run} \
        "$APPDIR" \
        "$OUTPUT_PATH" \
        2>&1

    if [ -f "$OUTPUT_PATH" ]; then
        chmod +x "$OUTPUT_PATH"
        SIZE=$(du -sh "$OUTPUT_PATH" | cut -f1)
        log_success "AppImage created: $OUTPUT_PATH ($SIZE)"
    else
        log_error "AppImage build failed — output file not found."
        exit 1
    fi
}

# ─── Post-Build Verification ─────────────────────────────────────────────────

verify_appimage() {
    log_info "Verifying AppImage..."

    OUTPUT_PATH="${SCRIPT_DIR}/${OUTPUT_NAME}"

    if [ ! -f "$OUTPUT_PATH" ]; then
        log_error "AppImage not found at $OUTPUT_PATH"
        exit 1
    fi

    # Check it's executable
    if [ ! -x "$OUTPUT_PATH" ]; then
        log_error "AppImage is not executable."
        exit 1
    fi

    log_success "AppImage verified: $OUTPUT_PATH"
    echo ""
    echo "────────────────────────────────────────────────────────"
    echo "  Build complete!"
    echo "  Output: $OUTPUT_PATH"
    echo ""
    echo "  To run:"
    echo "    ./${OUTPUT_NAME}"
    echo ""
    echo "  To install system-wide:"
    echo "    cp ${OUTPUT_NAME} ~/.local/bin/typeflow"
    echo "    chmod +x ~/.local/bin/typeflow"
    echo "────────────────────────────────────────────────────────"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    echo "╔══════════════════════════════════════╗"
    echo "║   TypeFlow AppImage Builder v1.0     ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    preflight_checks
    download_appimagetool
    create_appdir
    bundle_python_app
    install_data_files
    create_apprun
    build_appimage
    verify_appimage
}

main "$@"
