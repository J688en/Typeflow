# TypeFlow

**Type naturally. Anywhere.**

TypeFlow lets you paste a block of text, then simulates natural human typing into any application — character by character, with human-like timing, pauses, and even subtle typos that get corrected.

![TypeFlow](https://img.shields.io/badge/version-1.0.0-blue) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Natural Timing** — Random delays between keystrokes, pauses after punctuation, micro-hesitations
- **Human-like Typos** — Occasional adjacent-key mistakes that get immediately corrected (~4% rate)
- **Flexible Control** — 5-second countdown timer or global hotkey trigger (Cmd/Ctrl+Shift+T)
- **Adjustable Speed** — 30-120 WPM slider with live preview
- **Native Experience** — Built natively for each platform with OS-specific design language

## Downloads

| Platform | Format | Requirements |
|----------|--------|-------------|
| **macOS** | `.dmg` | macOS 12 Monterey or later, Apple Silicon & Intel |
| **Windows** | `.exe` | Windows 10 or later, x64 |
| **Linux** | `.AppImage` | Ubuntu 20.04+ / Fedora 36+, x64 |

Download from the [Releases](https://github.com/J688en/typeflow/releases) page or the [TypeFlow website](https://j688en.github.io/typeflow/).

## Platform Details

### macOS (Swift/SwiftUI)
- Native SwiftUI interface following macOS Human Interface Guidelines
- CGEvent-based keystroke injection with full Unicode support
- Accessibility permission handling with guided setup
- Global hotkeys via CGEventTap

### Windows (C#/WPF/.NET 8)
- Fluent Design with Windows 11 styling
- SendInput API with KEYEVENTF_UNICODE for keystroke simulation
- MVVM architecture with CommunityToolkit.Mvvm
- System theme detection (light/dark)

### Linux (Python/GTK4/libadwaita)
- GNOME HIG-compliant with Adwaita widgets
- xdotool (X11) / ydotool (Wayland) backends
- pynput-based global hotkey listener
- AppImage distribution with bundled dependencies

## Building from Source

### macOS
```bash
cd macos
./build-dmg.sh
```
Requires Xcode on macOS.

### Windows
```powershell
cd windows
.\build.bat
```
Requires .NET 8 SDK. Or build on any OS:
```bash
dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:EnableWindowsTargeting=true
```

### Linux
```bash
cd linux
./build-appimage.sh
```
Requires Python 3.10+, GTK4, libadwaita.

## Website

The `website/` directory contains the download page, deployable to GitHub Pages.

## License

MIT License — see [LICENSE](LICENSE) for details.
