# TypeFlow

**TypeFlow** is a native macOS app that simulates natural, human-like typing into any application. Paste your text, choose a speed (30–120 WPM), optionally enable typo simulation, and let TypeFlow type it character-by-character with realistic timing variation.

---

## Features

| Feature | Details |
|---|---|
| **Text input** | Large paste area with word and character count |
| **WPM control** | Slider from 30–120 WPM with live feedback |
| **Typo simulation** | ~4% chance per keystroke — mistype, pause, backspace, correct |
| **Countdown mode** | 5-second countdown before typing begins |
| **Global hotkey** | Arm TypeFlow, switch apps, press **⌘⇧T** to start |
| **Stop hotkey** | **Escape** or **⌘⇧S** stops typing immediately |
| **Progress bar** | Live progress with character count and status badge |
| **Dark mode** | Full support via SwiftUI automatic adaptation |
| **Accessibility check** | Friendly onboarding if permission isn't granted |

---

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (for building)
- **Accessibility permission** must be granted in System Settings → Privacy & Security → Accessibility

---

## Building with Xcode (recommended)

1. **Clone or download** this repository:
   ```bash
   git clone <repo-url>
   cd typeflow-macos
   ```

2. **Open the project in Xcode:**
   ```bash
   open TypeFlow.xcodeproj
   ```

3. **Set your Development Team:**
   - In the project navigator, select the `TypeFlow` target
   - Go to **Signing & Capabilities**
   - Choose your Apple Developer team (or use "Personal Team" for local testing)

4. **Build and run:**
   - Press **⌘R** or choose **Product → Run**
   - The app will launch and prompt for Accessibility permission on first run

---

## Building from the Command Line (xcodebuild)

```bash
cd typeflow-macos

# Build Release
xcodebuild \
  -project TypeFlow.xcodeproj \
  -scheme TypeFlow \
  -configuration Release \
  -derivedDataPath build \
  build

# The app is at:
# build/Build/Products/Release/TypeFlow.app
```

---

## Creating a DMG for Distribution

After building the Release `.app`:

```bash
# 1. Create a staging directory
mkdir -p dist/TypeFlow

# 2. Copy the app
cp -R "build/Build/Products/Release/TypeFlow.app" dist/TypeFlow/

# 3. Create a symbolic link to /Applications
ln -s /Applications dist/TypeFlow/Applications

# 4. Create the DMG
hdiutil create \
  -volname "TypeFlow" \
  -srcfolder dist/TypeFlow \
  -ov \
  -format UDZO \
  dist/TypeFlow.dmg

echo "DMG created at dist/TypeFlow.dmg"
```

### Optional: Notarize for Gatekeeper

If distributing outside the Mac App Store, notarize the app:

```bash
# Code sign first (requires Apple Developer account)
codesign \
  --deep \
  --force \
  --options runtime \
  --sign "Developer ID Application: Your Name (TEAMID)" \
  "build/Build/Products/Release/TypeFlow.app"

# Submit for notarization
xcrun notarytool submit dist/TypeFlow.dmg \
  --apple-id "your@apple.id" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait

# Staple the notarization ticket
xcrun stapler staple dist/TypeFlow.dmg
```

---

## Project Structure

```
typeflow-macos/
├── TypeFlow.xcodeproj/          # Xcode project file
│   └── project.pbxproj
├── TypeFlow/
│   ├── Sources/TypeFlow/
│   │   ├── TypeFlowApp.swift    # App entry point (@main)
│   │   ├── ContentView.swift    # Main window UI
│   │   ├── SettingsView.swift   # Settings/preferences
│   │   ├── PermissionView.swift # Accessibility onboarding
│   │   ├── TypingEngine.swift   # CGEvent keystroke simulation
│   │   ├── PermissionManager.swift  # AXIsProcessTrusted() wrapper
│   │   └── HotkeyManager.swift  # Global CGEventTap hotkeys
│   ├── Assets.xcassets/         # App icon and accent color
│   ├── Info.plist               # Bundle metadata + accessibility description
│   └── TypeFlow.entitlements    # Entitlements (sandbox disabled for CGEvent)
├── Package.swift                # SPM manifest (for CI / swift build)
└── README.md                    # This file
```

---

## How TypeFlow Works

### Typing Engine

TypeFlow calculates a base delay between characters:

```
base_delay = 60 / (wpm × 5)   // seconds per character
```

Each keystroke gets ±30% random jitter applied, so at 60 WPM:
- Base: `60 / (60 × 5)` = 200ms per character
- Range: 140ms – 260ms per keystroke

**Natural pauses:**
- After `.`, `!`, `?`: 1.8–2.5× base delay
- After `,`, `;`, `:`: 1.3–1.7× base delay
- Every 15–30 characters: extra 150–450ms micro-pause

### Typo Simulation (~4% chance per keystroke)

1. Types a wrong character (QWERTY-adjacent to the correct one)
2. Pauses 200–400ms (as if noticing the mistake)
3. Presses Backspace
4. Pauses 100–200ms
5. Types the correct character

### Keystroke Injection

TypeFlow uses `CGEvent` with `CGEventType.keyDown/keyUp` and `keyboardSetUnicodeString()` to post Unicode characters directly to the HID event stream, which delivers them to whatever application has keyboard focus.

**This requires Accessibility permission** — macOS requires it for any app that programmatically injects input events.

### Global Hotkeys

Registered via `CGEvent.tapCreate(.cgSessionEventTap)`:
- **⌘⇧T** — Start typing (hotkey mode only)
- **⌘⇧S** / **Escape** — Stop typing

---

## Accessibility Permission

On first launch, TypeFlow will show an onboarding banner if Accessibility access isn't granted.

**To grant access manually:**
1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the lock icon and enter your password
3. Find TypeFlow in the list and enable it
4. If TypeFlow isn't listed, click **+** and navigate to the app

TypeFlow polls every 2 seconds while the permission prompt is shown and automatically dismisses the banner once access is granted.

---

## License

MIT — see LICENSE file.
