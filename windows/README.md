# TypeFlow — Natural Typing Simulator for Windows

TypeFlow lets you paste a block of text and then simulates natural human typing into any application — character by character, with randomized timing, realistic pauses, and optional typo simulation.

---

## Features

| Feature | Details |
|---|---|
| **Text input** | Paste or type any amount of text; live character/word counter |
| **WPM slider** | 30–120 WPM, adjustable in real time before starting |
| **Typo simulation** | ~4% random mis-types with realistic self-correction (backspace + retype) |
| **Start methods** | 5-second countdown overlay **or** global hotkey (`Ctrl+Shift+T`) |
| **Stop** | Escape key, `Ctrl+Shift+S`, or the Stop button |
| **Progress bar** | Live progress with percentage |
| **Dark/Light mode** | Follows Windows 11 system theme; manual toggle in title bar |
| **Fluent Design** | Rounded cards, Windows-blue accent, Segoe UI Variable, DPI-aware |

---

## Requirements

- **Windows 10 or Windows 11** (x64)
- [**.NET 8 Desktop Runtime**](https://dotnet.microsoft.com/download/dotnet/8.0) or SDK

---

## How to Build

### Option A — .NET CLI (quickest)

```powershell
# 1. Clone or copy the project folder
cd path\to\typeflow-windows

# 2. Restore NuGet packages
dotnet restore

# 3. Build in Release mode
dotnet build -c Release

# 4. Run directly
dotnet run
```

The executable is placed at:
```
bin\Release\net8.0-windows\win-x64\TypeFlow.exe
```

### Option B — Publish to self-contained EXE

To create a single-file, no-install EXE:

```powershell
dotnet publish -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o .\publish
```

The final EXE is at `publish\TypeFlow.exe` (~60–80 MB self-contained).

### Option C — Framework-dependent EXE (smaller)

```powershell
dotnet publish -c Release -r win-x64 --self-contained false `
    -p:PublishSingleFile=true `
    -o .\publish-small
```

Requires .NET 8 Desktop Runtime to be installed on the target machine (~7 MB EXE).

### Option D — Visual Studio

1. Open `TypeFlow.csproj` in Visual Studio 2022 (17.8+)
2. Select **Release | x64**
3. Press **F5** to run or **Ctrl+Shift+B** to build
4. Use **Publish...** from the project right-click menu to create an EXE

---

## Usage

1. **Paste your text** into the large text box.
2. **Adjust the WPM slider** (30–120).
3. **Toggle Typo Simulation** on or off.
4. **Choose a start method:**
   - *5-second countdown* — click **Start Typing**, then quickly click into your target app. TypeFlow will start typing after the countdown.
   - *Hotkey* — select the hotkey option, click into your target app, then press **Ctrl+Shift+T**.
5. **Stop** at any time with **Esc**, **Ctrl+Shift+S**, or the Stop button.

---

## Project Structure

```
TypeFlow/
├── TypeFlow.csproj                 .NET 8 WPF project file
├── app.manifest                    DPI awareness + UAC manifest
├── App.xaml / App.xaml.cs          Application entry; theme management
├── MainWindow.xaml                 Main UI (XAML Fluent Design layout)
├── MainWindow.xaml.cs              Code-behind: hotkeys, events
├── ViewModels/
│   └── MainViewModel.cs            MVVM ViewModel (CommunityToolkit.Mvvm)
├── Services/
│   ├── TypingEngine.cs             SendInput typing engine + timing logic
│   └── HotkeyManager.cs           Win32 RegisterHotKey wrapper
├── Converters/
│   ├── BoolToVisibilityConverter.cs
│   ├── DoubleToPercentConverter.cs
│   ├── EnumToBoolConverter.cs
│   ├── StatusToColorConverter.cs
│   └── StatusToTextConverter.cs
└── Themes/
    ├── LightTheme.xaml             Windows 11 light palette
    └── DarkTheme.xaml              Windows 11 dark palette
```

---

## Architecture

**Pattern:** MVVM using [CommunityToolkit.Mvvm](https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/) (source generators, `[ObservableProperty]`, `[RelayCommand]`).

**Typing Engine (`TypingEngine.cs`)**
- Uses `SendInput` (user32.dll P/Invoke) with `KEYEVENTF_UNICODE` flags so any Unicode character works correctly.
- Base delay = `(60000 ms / WPM) / 5 chars-per-word`
- Per-keystroke variation: ±30% random multiplier
- Post-punctuation pauses: 1.5–2× for `.!?`, 1.2–1.5× for `,;:`
- Micro-pauses every 15–30 characters (80–300ms extra)
- Typo simulation: adjacent QWERTY key substitution, ~4% probability

**Hotkey Manager (`HotkeyManager.cs`)**
- Registers `WM_HOTKEY` via `RegisterHotKey` on the window handle
- Hooks the window's `HwndSource` message pump
- Gracefully degrades if another app has claimed the combo

**Theme System**
- Two `ResourceDictionary` files (Light/Dark) swapped at runtime
- Detects system theme via `HKCU\...\Themes\Personalize\AppsUseLightTheme`
- Listens for `SystemEvents.UserPreferenceChanged` for live switching
- Manual toggle button in title bar

---

## Hotkeys

| Action | Hotkey |
|---|---|
| Start typing (if hotkey mode) | `Ctrl+Shift+T` |
| Stop typing | `Ctrl+Shift+S` or `Escape` |

---

## Notes

- TypeFlow must be running and your cursor placed in the target application before typing begins.
- Some applications (games, UAC-elevated windows) may block `SendInput`. Run TypeFlow as Administrator if you encounter issues with specific apps.
- The `KEYEVENTF_UNICODE` approach works for most standard text fields. Applications that intercept WM_KEYDOWN at a low level may behave differently.

---

## Pre-built EXE

A ready-to-run self-contained executable is provided in the `dist/` folder:

```
dist/TypeFlow-1.0.0-Setup.exe   (~69 MB, no install required)
```

Just copy `TypeFlow-1.0.0-Setup.exe` to any Windows 10/11 x64 machine and run it — no .NET runtime installation needed.

---

## One-Click Build Scripts

If you want to rebuild the EXE yourself on a Windows machine:

| Script | How to run |
|---|---|
| `build.bat` | Double-click in Explorer, or run from Command Prompt |
| `build.ps1` | Right-click → "Run with PowerShell", or `.\build.ps1` in a terminal |

Both scripts:
1. Verify the .NET 8 SDK is installed
2. Restore NuGet packages
3. Publish a single-file self-contained `win-x64` EXE
4. Copy the result to `dist\TypeFlow-1.0.0-Setup.exe`

> **Note:** WPF requires the Windows Desktop SDK, so these scripts must be run on a Windows 10/11 machine with the [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) installed. Cross-compiling from Linux/macOS is not supported for WPF projects.
