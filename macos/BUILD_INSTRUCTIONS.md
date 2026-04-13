# TypeFlow macOS Build Instructions

## Prerequisites

macOS apps built with Swift/SwiftUI **must be compiled on a Mac with Xcode installed**. The Xcode toolchain is macOS-only and cannot run on Linux or Windows.

## Requirements

- A Mac running macOS 12 (Monterey) or later
- [Xcode](https://apps.apple.com/us/app/xcode/id497799835) installed from the Mac App Store
- Xcode Command Line Tools: run `xcode-select --install` if not already installed

## Building the DMG

1. Clone or copy this repository to your Mac.
2. Open a Terminal and navigate to the `typeflow-macos/` directory.
3. Run the build script:

   ```bash
   ./build-dmg.sh
   ```

4. The script will:
   - Verify you are on macOS with Xcode available
   - Compile TypeFlow in Release configuration via `xcodebuild`
   - Package the resulting `.app` bundle into a DMG with an Applications symlink

5. When complete, the DMG will be located at:

   ```
   build/TypeFlow-1.0.0.dmg
   ```

## Deploying to the Website

After building, copy the DMG to the website downloads folder:

```bash
cp build/TypeFlow-1.0.0.dmg ../typeflow-website/downloads/TypeFlow-1.0.0.dmg
```

The website's download page should then serve the file from `downloads/TypeFlow-1.0.0.dmg`.

## Troubleshooting

| Error | Fix |
|---|---|
| `This script must be run on macOS` | You are on Linux/Windows — build must happen on a Mac |
| `Xcode command line tools not found` | Run `xcode-select --install` |
| `Could not find built TypeFlow.app` | Check `xcodebuild` output above for compilation errors |
| Code signing errors | Open `TypeFlow.xcodeproj` in Xcode and configure your signing team |
