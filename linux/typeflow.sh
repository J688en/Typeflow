#!/usr/bin/env bash
# TypeFlow Launcher Script
# Runs the TypeFlow application from the source directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Check Python ───────────────────────────────────────────────────────────

if ! command -v python3 &>/dev/null; then
    echo "Error: python3 not found. Please install Python 3.10 or later." >&2
    exit 1
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
REQUIRED_MAJOR=3
REQUIRED_MINOR=10

ACTUAL_MAJOR=$(echo "$PYTHON_VERSION" | cut -d. -f1)
ACTUAL_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

if [ "$ACTUAL_MAJOR" -lt "$REQUIRED_MAJOR" ] || \
   ([ "$ACTUAL_MAJOR" -eq "$REQUIRED_MAJOR" ] && [ "$ACTUAL_MINOR" -lt "$REQUIRED_MINOR" ]); then
    echo "Error: Python $REQUIRED_MAJOR.$REQUIRED_MINOR or later required (found $PYTHON_VERSION)." >&2
    exit 1
fi

# ─── Check GTK4 / libadwaita ────────────────────────────────────────────────

if ! python3 -c "import gi; gi.require_version('Gtk', '4.0'); from gi.repository import Gtk" &>/dev/null 2>&1; then
    echo "Error: GTK4 Python bindings (PyGObject) not found." >&2
    echo "Install with: sudo apt install python3-gi gir1.2-gtk-4.0" >&2
    exit 1
fi

if ! python3 -c "import gi; gi.require_version('Adw', '1'); from gi.repository import Adw" &>/dev/null 2>&1; then
    echo "Error: libadwaita Python bindings not found." >&2
    echo "Install with: sudo apt install gir1.2-adw-1" >&2
    exit 1
fi

# ─── Check optional dependencies ────────────────────────────────────────────

if ! command -v xdotool &>/dev/null && ! command -v ydotool &>/dev/null; then
    echo "Warning: Neither xdotool nor ydotool found." >&2
    echo "TypeFlow requires one of these for keystroke simulation." >&2
    echo "  X11:    sudo apt install xdotool" >&2
    echo "  Wayland: sudo apt install ydotool" >&2
    echo ""
    echo "Continuing anyway — you can still configure settings." >&2
fi

if ! python3 -c "import pynput" &>/dev/null 2>&1; then
    echo "Info: pynput not found — global hotkeys will be disabled." >&2
    echo "Install with: pip install pynput" >&2
fi

# ─── Launch ─────────────────────────────────────────────────────────────────

cd "$SCRIPT_DIR"

# If running inside a virtual environment, use its Python
if [ -f "$SCRIPT_DIR/.venv/bin/python3" ]; then
    exec "$SCRIPT_DIR/.venv/bin/python3" -m typeflow "$@"
else
    exec python3 -m typeflow "$@"
fi
