using System.Runtime.InteropServices;
using System.Text;

namespace TypeFlow.Services;

/// <summary>
/// Core typing engine — sends keystrokes to the active window using
/// the Win32 SendInput API to simulate natural human typing.
/// </summary>
public class TypingEngine
{
    // ──────────────────────────────────────────────────────────────────
    // Win32 P/Invoke definitions
    // ──────────────────────────────────────────────────────────────────

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [DllImport("user32.dll")]
    private static extern short VkKeyScan(char ch);

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public INPUTUNION u;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct INPUTUNION
    {
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx, dy, mouseData;
        public uint dwFlags, time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HARDWAREINPUT
    {
        public uint uMsg;
        public ushort wParamL, wParamH;
    }

    private const uint INPUT_KEYBOARD  = 1;
    private const uint KEYEVENTF_KEYDOWN = 0x0000;
    private const uint KEYEVENTF_KEYUP   = 0x0002;
    private const uint KEYEVENTF_UNICODE  = 0x0004;
    private const ushort VK_BACK  = 0x08;
    private const ushort VK_SHIFT = 0x10;

    // ──────────────────────────────────────────────────────────────────
    // Fields
    // ──────────────────────────────────────────────────────────────────

    private readonly Random _rng = new();
    private CancellationTokenSource? _cts;

    // ──────────────────────────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────────────────────────

    /// <summary>Fired after each character is sent; arg is 0.0–1.0 progress.</summary>
    public event Action<double>? ProgressChanged;

    /// <summary>Fired when typing finishes or is stopped.</summary>
    public event Action? TypingFinished;

    // ──────────────────────────────────────────────────────────────────
    // Public API
    // ──────────────────────────────────────────────────────────────────

    public bool IsTyping => _cts != null && !_cts.IsCancellationRequested;

    /// <summary>
    /// Begins typing the given text asynchronously.
    /// </summary>
    /// <param name="text">Text to type.</param>
    /// <param name="wpm">Words per minute (30–120).</param>
    /// <param name="typoEnabled">Whether to occasionally mis-type.</param>
    public async Task StartTypingAsync(string text, int wpm, bool typoEnabled)
    {
        // Cancel any previous session
        Stop();

        _cts = new CancellationTokenSource();
        var token = _cts.Token;

        try
        {
            await Task.Run(() => TypeTextAsync(text, wpm, typoEnabled, token), token);
        }
        catch (OperationCanceledException)
        {
            // Expected when stopped
        }
        finally
        {
            TypingFinished?.Invoke();
        }
    }

    /// <summary>Stops typing immediately.</summary>
    public void Stop()
    {
        _cts?.Cancel();
        _cts = null;
    }

    // ──────────────────────────────────────────────────────────────────
    // Core typing loop
    // ──────────────────────────────────────────────────────────────────

    private async Task TypeTextAsync(string text, int wpm, bool typoEnabled, CancellationToken token)
    {
        if (string.IsNullOrEmpty(text)) return;

        // Average characters per word = 5, including trailing space
        // Base delay per character in milliseconds
        double baseDelayMs = (60_000.0 / wpm) / 5.0;

        int charsSinceLastPause = 0;
        int nextMicroPauseAt = GetNextMicroPauseInterval();

        for (int i = 0; i < text.Length; i++)
        {
            token.ThrowIfCancellationRequested();

            char ch = text[i];

            // ── Typo simulation ──────────────────────────────────────
            if (typoEnabled && ShouldMistype(ch))
            {
                char wrongChar = GetRandomNearbyChar(ch);
                if (wrongChar != '\0' && wrongChar != ch)
                {
                    // Type the wrong character
                    SendChar(wrongChar);
                    await DelayAsync((int)(baseDelayMs * (0.8 + _rng.NextDouble() * 0.5)), token);

                    // Pause as if noticing the mistake
                    await DelayAsync(_rng.Next(200, 401), token);

                    // Backspace
                    SendBackspace();
                    await DelayAsync(_rng.Next(100, 201), token);
                }
            }

            // ── Type the correct character ────────────────────────────
            SendChar(ch);

            // ── Calculate next delay ─────────────────────────────────
            double delay = baseDelayMs;

            // Random variation ±30%
            delay *= 0.7 + _rng.NextDouble() * 0.6;

            // Longer pause after sentence/clause endings
            if (ch == '.' || ch == '!' || ch == '?')
                delay *= 1.5 + _rng.NextDouble() * 0.5;  // 1.5–2× base
            else if (ch == ',' || ch == ';' || ch == ':')
                delay *= 1.2 + _rng.NextDouble() * 0.3;  // 1.2–1.5× base

            // Micro-pause every 15–30 characters (natural thinking pause)
            charsSinceLastPause++;
            if (charsSinceLastPause >= nextMicroPauseAt)
            {
                delay += _rng.Next(80, 300); // 80–300ms extra
                charsSinceLastPause = 0;
                nextMicroPauseAt = GetNextMicroPauseInterval();
            }

            await DelayAsync((int)delay, token);

            // Report progress
            double progress = (double)(i + 1) / text.Length;
            ProgressChanged?.Invoke(progress);
        }
    }

    // ──────────────────────────────────────────────────────────────────
    // SendInput helpers
    // ──────────────────────────────────────────────────────────────────

    /// <summary>Sends a Unicode character using SendInput.</summary>
    private static void SendChar(char ch)
    {
        // Use KEYEVENTF_UNICODE to handle any Unicode character correctly
        var inputs = new INPUT[]
        {
            new INPUT
            {
                type = INPUT_KEYBOARD,
                u = new INPUTUNION
                {
                    ki = new KEYBDINPUT
                    {
                        wVk   = 0,
                        wScan = ch,
                        dwFlags = KEYEVENTF_UNICODE,
                        time  = 0,
                        dwExtraInfo = IntPtr.Zero
                    }
                }
            },
            new INPUT
            {
                type = INPUT_KEYBOARD,
                u = new INPUTUNION
                {
                    ki = new KEYBDINPUT
                    {
                        wVk   = 0,
                        wScan = ch,
                        dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                        time  = 0,
                        dwExtraInfo = IntPtr.Zero
                    }
                }
            }
        };

        SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT)));
    }

    /// <summary>Sends a Backspace key press.</summary>
    private static void SendBackspace()
    {
        var inputs = new INPUT[]
        {
            new INPUT
            {
                type = INPUT_KEYBOARD,
                u = new INPUTUNION
                {
                    ki = new KEYBDINPUT
                    {
                        wVk   = VK_BACK,
                        wScan = 0,
                        dwFlags = KEYEVENTF_KEYDOWN,
                        time  = 0,
                        dwExtraInfo = IntPtr.Zero
                    }
                }
            },
            new INPUT
            {
                type = INPUT_KEYBOARD,
                u = new INPUTUNION
                {
                    ki = new KEYBDINPUT
                    {
                        wVk   = VK_BACK,
                        wScan = 0,
                        dwFlags = KEYEVENTF_KEYUP,
                        time  = 0,
                        dwExtraInfo = IntPtr.Zero
                    }
                }
            }
        };

        SendInput((uint)inputs.Length, inputs, Marshal.SizeOf(typeof(INPUT)));
    }

    // ──────────────────────────────────────────────────────────────────
    // Typo helpers
    // ──────────────────────────────────────────────────────────────────

    // ~4% chance of a typo on printable alphabetic characters
    private bool ShouldMistype(char ch)
        => char.IsLetter(ch) && _rng.NextDouble() < 0.04;

    // Adjacent keys on a QWERTY keyboard for realistic-looking typos
    private static readonly Dictionary<char, string> _adjacentKeys = new()
    {
        ['a'] = "sqwz",  ['b'] = "vghn",  ['c'] = "xdfv",  ['d'] = "serfcx",
        ['e'] = "wrsdf",  ['f'] = "drtgvc", ['g'] = "ftyhbv", ['h'] = "gyujnb",
        ['i'] = "ujklo",  ['j'] = "huikmnb",['k'] = "jiolm",  ['l'] = "kop",
        ['m'] = "njk",    ['n'] = "bhjm",   ['o'] = "iklp",   ['p'] = "ol",
        ['q'] = "wa",     ['r'] = "edft",   ['s'] = "awedxz", ['t'] = "rfgy",
        ['u'] = "yhij",   ['v'] = "cfgb",   ['w'] = "qase",   ['x'] = "zsdc",
        ['y'] = "tghu",   ['z'] = "asx"
    };

    private char GetRandomNearbyChar(char ch)
    {
        char lower = char.ToLower(ch);
        if (!_adjacentKeys.TryGetValue(lower, out string? neighbors) || neighbors.Length == 0)
            return '\0';

        char nearby = neighbors[_rng.Next(neighbors.Length)];
        // Preserve case
        return char.IsUpper(ch) ? char.ToUpper(nearby) : nearby;
    }

    private int GetNextMicroPauseInterval() => _rng.Next(15, 31);

    // ──────────────────────────────────────────────────────────────────
    // Delay helper (cancellable)
    // ──────────────────────────────────────────────────────────────────

    private static async Task DelayAsync(int ms, CancellationToken token)
    {
        if (ms > 0)
            await Task.Delay(ms, token);
    }
}
