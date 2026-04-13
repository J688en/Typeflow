using System.Windows;
using Microsoft.Win32;

namespace TypeFlow;

/// <summary>
/// Application entry point. Handles startup, shutdown, and system
/// theme detection / hot-switching between Light and Dark themes.
/// </summary>
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Apply theme matching the current Windows appearance setting
        ApplySystemTheme();

        // Listen for system theme changes (Windows 11 settings change)
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
    }

    protected override void OnExit(ExitEventArgs e)
    {
        SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
        base.OnExit(e);
    }

    // ──────────────────────────────────────────────────────────────────
    // Theme management
    // ──────────────────────────────────────────────────────────────────

    /// <summary>
    /// Reads the Windows "AppsUseLightTheme" registry value to decide
    /// whether to load LightTheme.xaml or DarkTheme.xaml.
    /// </summary>
    public void ApplySystemTheme()
    {
        bool isDark = IsSystemDarkMode();
        ApplyTheme(isDark);
    }

    public void ApplyTheme(bool isDark)
    {
        string themeUri = isDark
            ? "Themes/DarkTheme.xaml"
            : "Themes/LightTheme.xaml";

        var dict = Resources.MergedDictionaries[0];
        dict.Source = new Uri(themeUri, UriKind.Relative);
    }

    private static bool IsSystemDarkMode()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            var value = key?.GetValue("AppsUseLightTheme");
            if (value is int intVal)
                return intVal == 0; // 0 = dark, 1 = light
        }
        catch { /* fall through to default */ }

        return false; // default: light
    }

    private void OnUserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
    {
        // This can fire on a non-UI thread, so dispatch to UI thread
        if (e.Category == UserPreferenceCategory.General)
        {
            Dispatcher.Invoke(ApplySystemTheme);
        }
    }
}
