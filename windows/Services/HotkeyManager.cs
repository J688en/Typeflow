using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;

namespace TypeFlow.Services;

/// <summary>
/// Registers and manages global hotkeys using the Win32 RegisterHotKey API.
/// Must be created after the main window handle is available.
/// </summary>
public class HotkeyManager : IDisposable
{
    // ──────────────────────────────────────────────────────────────────
    // Win32 P/Invoke
    // ──────────────────────────────────────────────────────────────────

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    // Modifier flags
    private const uint MOD_ALT     = 0x0001;
    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_SHIFT   = 0x0004;
    private const uint MOD_WIN     = 0x0008;
    private const uint MOD_NOREPEAT = 0x4000;

    // Virtual key codes
    private const uint VK_T = 0x54;   // T
    private const uint VK_S = 0x53;   // S
    private const uint VK_ESCAPE = 0x1B;

    // Hotkey IDs (arbitrary unique integers)
    private const int HOTKEY_ID_START = 9001;
    private const int HOTKEY_ID_STOP  = 9002;

    // WM_HOTKEY message
    private const int WM_HOTKEY = 0x0312;

    // ──────────────────────────────────────────────────────────────────
    // Fields
    // ──────────────────────────────────────────────────────────────────

    private readonly IntPtr _hwnd;
    private HwndSource? _hwndSource;
    private bool _disposed;

    // ──────────────────────────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────────────────────────

    /// <summary>Fired when Ctrl+Shift+T is pressed (start typing hotkey).</summary>
    public event Action? StartHotkeyPressed;

    /// <summary>Fired when Ctrl+Shift+S or Escape is pressed (stop hotkey).</summary>
    public event Action? StopHotkeyPressed;

    // ──────────────────────────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────────────────────────

    /// <summary>
    /// Creates a HotkeyManager and hooks into the specified WPF window's
    /// message pump via HwndSource.
    /// </summary>
    public HotkeyManager(Window window)
    {
        var helper = new WindowInteropHelper(window);
        helper.EnsureHandle();
        _hwnd = helper.Handle;

        _hwndSource = HwndSource.FromHwnd(_hwnd);
        _hwndSource?.AddHook(WndProc);
    }

    // ──────────────────────────────────────────────────────────────────
    // Registration
    // ──────────────────────────────────────────────────────────────────

    /// <summary>Registers Ctrl+Shift+T (start) and Ctrl+Shift+S (stop) hotkeys.</summary>
    public void RegisterHotkeys()
    {
        // Ctrl+Shift+T — start typing
        bool startOk = RegisterHotKey(_hwnd, HOTKEY_ID_START,
            MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, VK_T);

        // Ctrl+Shift+S — stop typing
        bool stopOk = RegisterHotKey(_hwnd, HOTKEY_ID_STOP,
            MOD_CONTROL | MOD_SHIFT | MOD_NOREPEAT, VK_S);

        if (!startOk || !stopOk)
        {
            // Hotkey registration can fail if another app has claimed it.
            // We swallow the error gracefully — the UI stop button still works.
            int err = Marshal.GetLastWin32Error();
            System.Diagnostics.Debug.WriteLine(
                $"[HotkeyManager] Registration partial failure (Win32 error {err}). " +
                "Another app may have claimed this hotkey combo.");
        }
    }

    /// <summary>Unregisters all hotkeys.</summary>
    public void UnregisterHotkeys()
    {
        UnregisterHotKey(_hwnd, HOTKEY_ID_START);
        UnregisterHotKey(_hwnd, HOTKEY_ID_STOP);
    }

    // ──────────────────────────────────────────────────────────────────
    // WndProc hook
    // ──────────────────────────────────────────────────────────────────

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_HOTKEY)
        {
            int id = wParam.ToInt32();
            switch (id)
            {
                case HOTKEY_ID_START:
                    StartHotkeyPressed?.Invoke();
                    handled = true;
                    break;
                case HOTKEY_ID_STOP:
                    StopHotkeyPressed?.Invoke();
                    handled = true;
                    break;
            }
        }
        return IntPtr.Zero;
    }

    // ──────────────────────────────────────────────────────────────────
    // Dispose
    // ──────────────────────────────────────────────────────────────────

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        UnregisterHotkeys();
        _hwndSource?.RemoveHook(WndProc);
        _hwndSource = null;
    }
}
