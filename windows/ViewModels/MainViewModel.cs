using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using System.Windows;
using System.Windows.Threading;
using TypeFlow.Services;

namespace TypeFlow.ViewModels;

/// <summary>
/// Enum representing the current application state.
/// </summary>
public enum AppStatus
{
    Idle,
    Countdown,
    Typing
}

/// <summary>
/// Enum for the start method the user has selected.
/// </summary>
public enum StartMethod
{
    Countdown,
    Hotkey
}

/// <summary>
/// Main ViewModel for the TypeFlow application.
/// Implements MVVM using CommunityToolkit.Mvvm source generators.
/// </summary>
public partial class MainViewModel : ObservableObject
{
    // ──────────────────────────────────────────────────────────────────
    // Services
    // ──────────────────────────────────────────────────────────────────

    private readonly TypingEngine _typingEngine;
    private DispatcherTimer? _countdownTimer;

    // ──────────────────────────────────────────────────────────────────
    // Observable properties
    // ──────────────────────────────────────────────────────────────────

    /// <summary>The text the user wants to type.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CharacterCount))]
    [NotifyPropertyChangedFor(nameof(WordCount))]
    [NotifyCanExecuteChangedFor(nameof(StartTypingCommand))]
    private string _inputText = string.Empty;

    /// <summary>Typing speed in words per minute.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(WpmLabel))]
    private int _wpm = 70;

    /// <summary>Whether the typo simulation is enabled.</summary>
    [ObservableProperty]
    private bool _typoEnabled = true;

    /// <summary>Selected start method (Countdown or Hotkey).</summary>
    [ObservableProperty]
    private StartMethod _selectedStartMethod = StartMethod.Countdown;

    /// <summary>Current application status (Idle, Countdown, Typing).</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsIdle))]
    [NotifyPropertyChangedFor(nameof(IsRunning))]
    [NotifyPropertyChangedFor(nameof(StatusLabel))]
    [NotifyCanExecuteChangedFor(nameof(StartTypingCommand))]
    [NotifyCanExecuteChangedFor(nameof(StopTypingCommand))]
    private AppStatus _status = AppStatus.Idle;

    /// <summary>Typing progress, 0.0 to 1.0.</summary>
    [ObservableProperty]
    private double _progress;

    /// <summary>Countdown seconds remaining.</summary>
    [ObservableProperty]
    private int _countdownSeconds = 5;

    /// <summary>Whether the countdown overlay is visible.</summary>
    [ObservableProperty]
    private bool _countdownVisible;

    /// <summary>Status message shown to the user (errors, hints, etc.).</summary>
    [ObservableProperty]
    private string _statusMessage = "Paste your text, configure settings, then start typing.";

    // ──────────────────────────────────────────────────────────────────
    // Computed properties
    // ──────────────────────────────────────────────────────────────────

    public bool IsIdle    => Status == AppStatus.Idle;
    public bool IsRunning => Status != AppStatus.Idle;

    public string WpmLabel => $"{Wpm} WPM";

    public int CharacterCount => InputText.Length;
    public int WordCount => string.IsNullOrWhiteSpace(InputText)
        ? 0
        : InputText.Split(new[] { ' ', '\n', '\r', '\t' },
              StringSplitOptions.RemoveEmptyEntries).Length;

    public string StatusLabel => Status switch
    {
        AppStatus.Idle      => "Ready",
        AppStatus.Countdown => $"Starting in {CountdownSeconds}…",
        AppStatus.Typing    => "Typing…",
        _                   => "Ready"
    };

    // ──────────────────────────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────────────────────────

    public MainViewModel()
    {
        _typingEngine = new TypingEngine();

        // Subscribe to engine events (marshal back to UI thread)
        _typingEngine.ProgressChanged += p =>
            Application.Current.Dispatcher.Invoke(() => Progress = p);

        _typingEngine.TypingFinished += () =>
            Application.Current.Dispatcher.Invoke(OnTypingFinished);
    }

    // ──────────────────────────────────────────────────────────────────
    // Commands
    // ──────────────────────────────────────────────────────────────────

    /// <summary>Start typing — respects the selected StartMethod.</summary>
    [RelayCommand(CanExecute = nameof(CanStartTyping))]
    private async Task StartTypingAsync()
    {
        if (!CanStartTyping()) return;

        if (SelectedStartMethod == StartMethod.Countdown)
            await RunCountdownThenTypeAsync();
        else
            await BeginTypingAsync();
    }

    private bool CanStartTyping()
        => Status == AppStatus.Idle && !string.IsNullOrWhiteSpace(InputText);

    /// <summary>Stop typing immediately.</summary>
    [RelayCommand(CanExecute = nameof(CanStopTyping))]
    private void StopTyping()
    {
        _countdownTimer?.Stop();
        _countdownTimer = null;
        CountdownVisible = false;

        _typingEngine.Stop();

        Status = AppStatus.Idle;
        StatusMessage = "Typing stopped.";
    }

    private bool CanStopTyping() => Status != AppStatus.Idle;

    // ──────────────────────────────────────────────────────────────────
    // Hotkey handlers (called from code-behind)
    // ──────────────────────────────────────────────────────────────────

    /// <summary>Called when the global start hotkey (Ctrl+Shift+T) fires.</summary>
    public async Task HandleStartHotkeyAsync()
    {
        if (Status == AppStatus.Idle && !string.IsNullOrWhiteSpace(InputText))
            await BeginTypingAsync();
    }

    /// <summary>Called when the global stop hotkey (Ctrl+Shift+S) fires.</summary>
    public void HandleStopHotkey() => StopTyping();

    // ──────────────────────────────────────────────────────────────────
    // Internal logic
    // ──────────────────────────────────────────────────────────────────

    private async Task RunCountdownThenTypeAsync()
    {
        Status = AppStatus.Countdown;
        CountdownSeconds = 5;
        CountdownVisible = true;
        StatusMessage = "Move cursor to target app. Typing starts soon…";

        var tcs = new TaskCompletionSource<bool>();

        _countdownTimer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(1)
        };

        _countdownTimer.Tick += (s, e) =>
        {
            CountdownSeconds--;
            OnPropertyChanged(nameof(StatusLabel));

            if (CountdownSeconds <= 0)
            {
                _countdownTimer.Stop();
                _countdownTimer = null;
                CountdownVisible = false;
                tcs.TrySetResult(true);
            }
        };

        _countdownTimer.Start();

        // Wait for countdown to finish (or be cancelled)
        await tcs.Task;

        if (Status == AppStatus.Countdown)
            await BeginTypingAsync();
    }

    private async Task BeginTypingAsync()
    {
        Status = AppStatus.Typing;
        Progress = 0;
        StatusMessage = "Typing in progress… Press Esc or Ctrl+Shift+S to stop.";

        await _typingEngine.StartTypingAsync(InputText, Wpm, TypoEnabled);
    }

    private void OnTypingFinished()
    {
        if (Status == AppStatus.Typing)
        {
            Status = AppStatus.Idle;
            StatusMessage = Progress >= 1.0
                ? "Done! All text has been typed."
                : "Typing stopped.";
        }
    }
}
