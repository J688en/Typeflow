using System.Windows;
using System.Windows.Input;
using TypeFlow.Services;
using TypeFlow.ViewModels;

namespace TypeFlow;

/// <summary>
/// Code-behind for MainWindow. Handles:
/// - Global hotkey registration/teardown
/// - Custom title bar dragging
/// - Keyboard shortcuts (Escape)
/// - Theme toggle button
/// - Countdown overlay animations
/// </summary>
public partial class MainWindow : Window
{
    // ──────────────────────────────────────────────────────────────────
    // Fields
    // ──────────────────────────────────────────────────────────────────

    private HotkeyManager? _hotkeyManager;
    private bool _isDarkTheme;

    // Convenience accessor to the ViewModel
    private MainViewModel ViewModel => (MainViewModel)DataContext;

    // ──────────────────────────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────────────────────────

    public MainWindow()
    {
        InitializeComponent();
    }

    // ──────────────────────────────────────────────────────────────────
    // Window event handlers
    // ──────────────────────────────────────────────────────────────────

    private void Window_Loaded(object sender, RoutedEventArgs e)
    {
        // Register global hotkeys now that the window handle exists
        _hotkeyManager = new HotkeyManager(this);
        _hotkeyManager.RegisterHotkeys();

        // Wire up hotkey events to ViewModel handlers
        _hotkeyManager.StartHotkeyPressed += async () =>
        {
            // Run on UI thread
            await Dispatcher.InvokeAsync(async () =>
                await ViewModel.HandleStartHotkeyAsync());
        };

        _hotkeyManager.StopHotkeyPressed += () =>
            Dispatcher.Invoke(() => ViewModel.HandleStopHotkey());

        // Detect initial theme from system
        _isDarkTheme = IsCurrentThemeDark();
        UpdateThemeButtonIcon();
    }

    private void Window_Closing(object sender, System.ComponentModel.CancelEventArgs e)
    {
        // Stop any active typing and unregister hotkeys
        ViewModel.HandleStopHotkey();
        _hotkeyManager?.Dispose();
    }

    // ──────────────────────────────────────────────────────────────────
    // Keyboard shortcut — Escape to stop
    // ──────────────────────────────────────────────────────────────────

    private void Window_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Escape)
        {
            ViewModel.HandleStopHotkey();
            e.Handled = true;
        }
    }

    // ──────────────────────────────────────────────────────────────────
    // Custom title bar drag
    // ──────────────────────────────────────────────────────────────────

    private void TitleBar_MouseLeftButtonDown(object sender, MouseButtonEventArgs e)
    {
        if (e.ButtonState == MouseButtonState.Pressed)
        {
            // Allow double-click to maximize/restore
            if (e.ClickCount == 2)
            {
                WindowState = WindowState == WindowState.Maximized
                    ? WindowState.Normal
                    : WindowState.Maximized;
                return;
            }
            DragMove();
        }
    }

    // ──────────────────────────────────────────────────────────────────
    // Buttons
    // ──────────────────────────────────────────────────────────────────

    private void ClearText_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.InputText = string.Empty;
        ViewModel.Progress = 0;
        InputTextBox.Focus();
    }

    private void ThemeToggleBtn_Click(object sender, RoutedEventArgs e)
    {
        _isDarkTheme = !_isDarkTheme;
        ((App)Application.Current).ApplyTheme(_isDarkTheme);
        UpdateThemeButtonIcon();
    }

    // ──────────────────────────────────────────────────────────────────
    // Theme helpers
    // ──────────────────────────────────────────────────────────────────

    private void UpdateThemeButtonIcon()
    {
        ThemeToggleBtn.Content = _isDarkTheme ? "☀" : "🌙";
        ThemeToggleBtn.ToolTip = _isDarkTheme
            ? "Switch to light theme"
            : "Switch to dark theme";
    }

    private static bool IsCurrentThemeDark()
    {
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            var value = key?.GetValue("AppsUseLightTheme");
            if (value is int intVal)
                return intVal == 0;
        }
        catch { }
        return false;
    }
}
