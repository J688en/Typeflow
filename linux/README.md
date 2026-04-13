# TypeFlow

**TypeFlow** is a native Linux desktop application for simulating natural human typing. Paste any block of text and TypeFlow types it into whatever application has focus — character by character, with realistic randomized timing, occasional "thinking" pauses, and optional typo simulation with auto-correction.

Built with Python, GTK4, and libadwaita for a first-class GNOME experience.

---

## Screenshots

TypeFlow follows GNOME Human Interface Guidelines and uses the Adwaita design system, so it looks at home in any GNOME environment and supports both light and dark modes automatically.

---

## Features

- **Adjustable WPM** — 30 to 120 words per minute with live preview
- **Typo Simulation** — Randomly mistypes ~4% of characters, pauses, then backspaces and types the correct character
- **Two Start Modes:**
  - **Countdown Timer** — Click Start, switch to your target app within 5 seconds
  - **Global Hotkey** — Arm the engine, then press `Ctrl+Shift+T` whenever you're ready
- **Stop Anytime** — Click Stop, press `Esc`, or press `Ctrl+Shift+S`
- **Live Progress Bar** — Shows typing progress with character counts
- **X11 and Wayland** — Uses `xdotool` on X11 or `ydotool` on Wayland

---

## Requirements

### Runtime

| Dependency | Purpose | Install |
|---|---|---|
| Python 3.10+ | Runtime | `sudo apt install python3` |
| PyGObject | GTK Python bindings | `sudo apt install python3-gi` |
| GTK4 typelibs | GTK4 GIR data | `sudo apt install gir1.2-gtk-4.0` |
| libadwaita typelibs | Adwaita widgets | `sudo apt install gir1.2-adw-1` |
| xdotool | X11 keystroke simulation | `sudo apt install xdotool` |
| ydotool | Wayland keystroke simulation | `sudo apt install ydotool` |
| pynput | Global hotkeys | `pip install pynput` |

**Note:** You need either `xdotool` (X11) or `ydotool` (Wayland), not both. `pynput` is optional but required for global hotkey support.

### One-liner install (Ubuntu/Debian, X11):

```bash
sudo apt install python3 python3-gi python3-gi-cairo gir1.2-gtk-4.0 gir1.2-adw-1 xdotool
pip install pynput
```

### One-liner install (Wayland):

```bash
sudo apt install python3 python3-gi python3-gi-cairo gir1.2-gtk-4.0 gir1.2-adw-1 ydotool
pip install pynput
```

---

## Installation & Running

### Run from Source

```bash
git clone https://github.com/typeflow/typeflow.git
cd typeflow

# Install Python dependencies
pip install -r requirements.txt

# Run
python3 -m typeflow
# or
chmod +x typeflow.sh && ./typeflow.sh
```

### Install System-wide (from source)

```bash
# Copy to local bin
cp typeflow.sh ~/.local/bin/typeflow
chmod +x ~/.local/bin/typeflow

# Install desktop entry
cp data/com.typeflow.app.desktop ~/.local/share/applications/
cp data/icons/com.typeflow.app.svg ~/.local/share/icons/hicolor/scalable/apps/

# Update icon cache
gtk-update-icon-cache ~/.local/share/icons/hicolor/
```

---

## Building the AppImage

TypeFlow can be packaged as a self-contained AppImage for distribution.

### Prerequisites

```bash
# Install build dependencies
sudo apt install python3-venv wget
```

### Build

```bash
chmod +x build-appimage.sh
./build-appimage.sh
```

The script will:
1. Download `appimagetool` automatically if not present
2. Create an `AppDir/` directory with the correct structure
3. Bundle the TypeFlow Python package and its pure-Python dependencies
4. Produce `TypeFlow-1.0.0-x86_64.AppImage` in the project root

### Run the AppImage

```bash
chmod +x TypeFlow-1.0.0-x86_64.AppImage
./TypeFlow-1.0.0-x86_64.AppImage
```

> **Note on GTK4 AppImages:** GTK4 and libadwaita must be present on the host system for correct theming. The AppImage bundles the Python application and dependencies, but relies on the system's GTK4 libraries. This is the recommended approach for GTK4 applications and ensures the app respects the user's theme and style preferences.

---

## AppDir Structure

```
AppDir/
├── AppRun                              # AppImage entry point (executable)
├── com.typeflow.app.desktop            # Desktop entry (AppImage spec)
├── com.typeflow.app.svg                # App icon (AppImage spec)
└── usr/
    ├── bin/
    │   └── typeflow                    # Launcher shell script
    ├── lib/
    │   └── typeflow/
    │       ├── typeflow/               # Python package
    │       │   ├── __init__.py
    │       │   ├── __main__.py
    │       │   ├── app.py
    │       │   ├── window.py
    │       │   ├── typing_engine.py
    │       │   └── hotkey_manager.py
    │       └── venv/                   # Bundled Python venv
    │           └── lib/site-packages/  # pynput and deps
    └── share/
        ├── applications/
        │   └── com.typeflow.app.desktop
        ├── icons/hicolor/scalable/apps/
        │   └── com.typeflow.app.svg
        └── metainfo/
            └── com.typeflow.app.metainfo.xml
```

---

## Project Structure

```
typeflow-linux/
├── typeflow/                   # Main Python package
│   ├── __init__.py             # Package metadata
│   ├── __main__.py             # Entry point
│   ├── app.py                  # Adw.Application subclass
│   ├── window.py               # Main window UI (GTK4/Adwaita)
│   ├── typing_engine.py        # Core typing simulation engine
│   └── hotkey_manager.py       # Global hotkey listener (pynput)
├── data/
│   ├── com.typeflow.app.desktop    # Desktop entry
│   ├── com.typeflow.app.metainfo.xml  # AppStream metadata
│   └── icons/
│       └── com.typeflow.app.svg    # App icon
├── typeflow.sh                 # Development launcher script
├── requirements.txt            # Python dependencies
├── build-appimage.sh           # AppImage build script
└── README.md                   # This file
```

---

## Architecture

### Typing Engine (`typing_engine.py`)

The engine runs in a background thread and uses these timing algorithms:

- **Base delay:** `60 / (wpm × 5)` seconds per character
- **Random variation:** ±30% of base delay per keystroke
- **Punctuation pause:** +50–120% extra delay after `.`, `!`, `?`; +30–70% after `,`, `;`, `:`
- **Micro-pauses:** Random 0.3–1.2s pause every 15–30 characters
- **Typo flow:** Type wrong char → wait 200–400ms → backspace → wait 100–200ms → type correct char

GTK UI updates are always dispatched via `GLib.idle_add()` to ensure thread safety.

### Backend Detection

TypeFlow auto-detects the display server and selects the appropriate keystroke backend:

1. Checks `WAYLAND_DISPLAY` and `XDG_SESSION_TYPE` env vars
2. On Wayland: prefers `ydotool`, falls back to `xdotool` (XWayland)
3. On X11: prefers `xdotool`, falls back to `ydotool`

### Hotkey Manager (`hotkey_manager.py`)

Uses `pynput` to listen for global key events in a background thread. When a hotkey combo is detected, it calls the registered callback, which uses `GLib.idle_add()` to marshal the action onto the GTK main thread.

---

## Wayland Notes

On Wayland, `ydotool` requires the `uinput` kernel module and appropriate permissions:

```bash
# Add yourself to the input group
sudo usermod -aG input $USER
# Load uinput module
sudo modprobe uinput
# Persist uinput loading at boot
echo "uinput" | sudo tee /etc/modules-load.d/uinput.conf
```

You may need to log out and back in for group changes to take effect.

---

## License

MIT License — see [LICENSE](LICENSE) for details.
