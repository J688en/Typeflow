"""
TypeFlow Typing Engine
Handles the core logic for simulating natural human typing.
Uses xdotool (X11) or ydotool (Wayland) for keystroke injection.
"""

import random
import subprocess
import threading
import os
import shutil
from typing import Callable, Optional
from gi.repository import GLib


# Characters that get longer pauses after them
PAUSE_CHARS = {'.', '!', '?', ',', ';', ':'}
LONG_PAUSE_CHARS = {'.', '!', '?'}

# Keyboard layout for typo simulation (adjacent keys)
ADJACENT_KEYS: dict[str, list[str]] = {
    'a': ['s', 'q', 'z', 'w'],
    'b': ['v', 'n', 'g', 'h'],
    'c': ['x', 'v', 'd', 'f'],
    'd': ['s', 'f', 'e', 'r', 'c', 'x'],
    'e': ['w', 'r', 'd', 's'],
    'f': ['d', 'g', 'r', 't', 'v', 'c'],
    'g': ['f', 'h', 't', 'y', 'b', 'v'],
    'h': ['g', 'j', 'y', 'u', 'n', 'b'],
    'i': ['u', 'o', 'k', 'j'],
    'j': ['h', 'k', 'u', 'i', 'm', 'n'],
    'k': ['j', 'l', 'i', 'o', 'm'],
    'l': ['k', 'o', 'p'],
    'm': ['n', 'j', 'k'],
    'n': ['b', 'm', 'h', 'j'],
    'o': ['i', 'p', 'k', 'l'],
    'p': ['o', 'l'],
    'q': ['w', 'a'],
    'r': ['e', 't', 'd', 'f'],
    's': ['a', 'd', 'w', 'e', 'z', 'x'],
    't': ['r', 'y', 'f', 'g'],
    'u': ['y', 'i', 'h', 'j'],
    'v': ['c', 'b', 'f', 'g'],
    'w': ['q', 'e', 'a', 's'],
    'x': ['z', 'c', 's', 'd'],
    'y': ['t', 'u', 'g', 'h'],
    'z': ['a', 's', 'x'],
}


def _detect_display_server() -> str:
    """Detect whether we're running on X11 or Wayland."""
    wayland_display = os.environ.get('WAYLAND_DISPLAY', '')
    xdg_session = os.environ.get('XDG_SESSION_TYPE', '').lower()
    if wayland_display or xdg_session == 'wayland':
        return 'wayland'
    return 'x11'


def _has_tool(name: str) -> bool:
    """Check if a CLI tool is available on PATH."""
    return shutil.which(name) is not None


class TypingBackend:
    """
    Abstraction over xdotool (X11) and ydotool (Wayland) for keystroke simulation.
    """

    def __init__(self) -> None:
        self.display_server = _detect_display_server()
        self._select_backend()

    def _select_backend(self) -> None:
        """Select appropriate backend based on display server and available tools."""
        if self.display_server == 'wayland':
            if _has_tool('ydotool'):
                self.backend = 'ydotool'
            elif _has_tool('xdotool'):
                # XWayland fallback
                self.backend = 'xdotool'
            else:
                self.backend = 'none'
        else:
            if _has_tool('xdotool'):
                self.backend = 'xdotool'
            elif _has_tool('ydotool'):
                self.backend = 'ydotool'
            else:
                self.backend = 'none'

    def type_char(self, char: str) -> bool:
        """
        Type a single character using the selected backend.
        Returns True on success, False on failure.
        """
        if self.backend == 'none':
            return False

        try:
            if self.backend == 'xdotool':
                return self._xdotool_type(char)
            elif self.backend == 'ydotool':
                return self._ydotool_type(char)
        except Exception:
            return False

        return False

    def press_backspace(self) -> bool:
        """Press the Backspace key."""
        if self.backend == 'none':
            return False
        try:
            if self.backend == 'xdotool':
                subprocess.run(
                    ['xdotool', 'key', 'BackSpace'],
                    check=True, capture_output=True, timeout=2
                )
                return True
            elif self.backend == 'ydotool':
                # Backspace keycode = 14
                subprocess.run(
                    ['ydotool', 'key', '14:1', '14:0'],
                    check=True, capture_output=True, timeout=2
                )
                return True
        except Exception:
            return False
        return False

    def _xdotool_type(self, char: str) -> bool:
        """Type a character using xdotool."""
        # Use --clearmodifiers to avoid modifier key interference
        # --delay 0 because we handle timing ourselves
        if char == '\n':
            subprocess.run(
                ['xdotool', 'key', '--clearmodifiers', 'Return'],
                check=True, capture_output=True, timeout=2
            )
        elif char == '\t':
            subprocess.run(
                ['xdotool', 'key', '--clearmodifiers', 'Tab'],
                check=True, capture_output=True, timeout=2
            )
        else:
            subprocess.run(
                ['xdotool', 'type', '--clearmodifiers', '--delay', '0', '--', char],
                check=True, capture_output=True, timeout=2
            )
        return True

    def _ydotool_type(self, char: str) -> bool:
        """Type a character using ydotool."""
        if char == '\n':
            subprocess.run(
                ['ydotool', 'key', '28:1', '28:0'],
                check=True, capture_output=True, timeout=2
            )
        else:
            subprocess.run(
                ['ydotool', 'type', '--', char],
                check=True, capture_output=True, timeout=2
            )
        return True

    @property
    def is_available(self) -> bool:
        """Returns True if a typing backend is available."""
        return self.backend != 'none'

    @property
    def backend_name(self) -> str:
        """Human-readable backend name."""
        names = {
            'xdotool': 'xdotool (X11)',
            'ydotool': 'ydotool (Wayland)',
            'none': 'None (not available)',
        }
        return names.get(self.backend, self.backend)


class TypingEngine:
    """
    Core typing engine that simulates natural human typing patterns.

    Features:
    - Randomized per-keystroke timing based on WPM setting
    - Longer pauses after punctuation
    - Occasional "thinking" micro-pauses
    - Realistic typo simulation with backspace correction
    - Thread-safe GTK progress updates via GLib.idle_add
    """

    def __init__(
        self,
        on_progress: Optional[Callable[[int, int], None]] = None,
        on_finished: Optional[Callable[[], None]] = None,
        on_error: Optional[Callable[[str], None]] = None,
        on_status: Optional[Callable[[str], None]] = None,
    ) -> None:
        """
        Initialize the typing engine.

        Args:
            on_progress: Callback(chars_typed, total_chars) for progress updates.
            on_finished: Callback when typing completes.
            on_error: Callback(error_message) when an error occurs.
            on_status: Callback(status_message) for status text updates.
        """
        self.on_progress = on_progress
        self.on_finished = on_finished
        self.on_error = on_error
        self.on_status = on_status

        self.backend = TypingBackend()
        self._stop_event = threading.Event()
        self._thread: Optional[threading.Thread] = None
        self._is_running = False

        # Configuration (set before calling start())
        self.wpm: int = 60
        self.typo_enabled: bool = True
        self.typo_rate: float = 0.04  # 4% chance per character
        self.text: str = ""

    @property
    def is_running(self) -> bool:
        return self._is_running

    def _base_delay(self) -> float:
        """
        Calculate base delay in seconds per character from WPM setting.
        Assumes average word = 5 characters.
        """
        chars_per_minute = self.wpm * 5
        return 60.0 / chars_per_minute

    def _char_delay(self, char: str) -> float:
        """
        Calculate realistic delay for a character with randomness.
        Punctuation chars get extra pause after them.
        """
        base = self._base_delay()
        # ±30% random variation
        variation = base * 0.30
        delay = base + random.uniform(-variation, variation)

        # Post-char pause for punctuation
        if char in LONG_PAUSE_CHARS:
            delay += base * random.uniform(0.8, 1.2)  # ~1x extra
        elif char in PAUSE_CHARS:
            delay += base * random.uniform(0.3, 0.7)  # ~0.5x extra

        return max(delay, 0.01)

    def _get_typo_char(self, correct_char: str) -> Optional[str]:
        """
        Return a plausible typo character adjacent to the given key,
        or None if no adjacent key is known.
        """
        lower = correct_char.lower()
        if lower in ADJACENT_KEYS:
            candidates = ADJACENT_KEYS[lower]
            typo = random.choice(candidates)
            # Preserve capitalization
            if correct_char.isupper():
                typo = typo.upper()
            return typo
        return None

    def _emit_progress(self, typed: int, total: int) -> None:
        """Thread-safe progress emission via GLib.idle_add."""
        if self.on_progress:
            GLib.idle_add(self.on_progress, typed, total)

    def _emit_finished(self) -> None:
        """Thread-safe finished signal."""
        if self.on_finished:
            GLib.idle_add(self.on_finished)

    def _emit_error(self, message: str) -> None:
        """Thread-safe error signal."""
        if self.on_error:
            GLib.idle_add(self.on_error, message)

    def _emit_status(self, message: str) -> None:
        """Thread-safe status update."""
        if self.on_status:
            GLib.idle_add(self.on_status, message)

    def _run_typing(self) -> None:
        """
        Internal thread method that performs the actual typing sequence.
        """
        text = self.text
        total = len(text)
        typed_count = 0
        chars_since_pause = 0
        next_micro_pause_at = random.randint(15, 30)

        self._emit_status("Typing...")

        for i, char in enumerate(text):
            if self._stop_event.is_set():
                self._emit_status("Stopped.")
                self._is_running = False
                return

            # Decide whether to make a typo on this character
            make_typo = (
                self.typo_enabled
                and char.isalpha()
                and random.random() < self.typo_rate
            )

            if make_typo:
                typo_char = self._get_typo_char(char)
                if typo_char:
                    # Type the wrong character
                    self.backend.type_char(typo_char)

                    # Pause before noticing the mistake (200-400ms)
                    pause = random.uniform(0.20, 0.40)
                    if self._stop_event.wait(pause):
                        self._emit_status("Stopped.")
                        self._is_running = False
                        return

                    # Backspace to erase
                    self.backend.press_backspace()

                    # Short pause after backspace (100-200ms)
                    pause = random.uniform(0.10, 0.20)
                    if self._stop_event.wait(pause):
                        self._emit_status("Stopped.")
                        self._is_running = False
                        return

            # Type the correct character
            success = self.backend.type_char(char)
            if not success and self.backend.backend == 'none':
                self._emit_error(
                    "No typing backend available.\n"
                    "Please install xdotool (X11) or ydotool (Wayland):\n"
                    "  sudo apt install xdotool\n"
                    "  # or for Wayland: sudo apt install ydotool"
                )
                self._is_running = False
                return

            typed_count += 1
            chars_since_pause += 1
            self._emit_progress(typed_count, total)

            # Micro-pause (thinking pause) every 15-30 chars
            if chars_since_pause >= next_micro_pause_at:
                chars_since_pause = 0
                next_micro_pause_at = random.randint(15, 30)
                # 0.3-1.2 second thinking pause
                pause = random.uniform(0.3, 1.2)
                if self._stop_event.wait(pause):
                    self._emit_status("Stopped.")
                    self._is_running = False
                    return

            # Normal inter-character delay
            delay = self._char_delay(char)
            if self._stop_event.wait(delay):
                self._emit_status("Stopped.")
                self._is_running = False
                return

        self._is_running = False
        self._emit_status("Done!")
        self._emit_finished()

    def start(self, delay_seconds: float = 0.0) -> None:
        """
        Start the typing sequence, optionally after a delay.

        Args:
            delay_seconds: Seconds to wait before beginning to type.
        """
        if self._is_running:
            return

        if not self.text.strip():
            if self.on_error:
                GLib.idle_add(self.on_error, "No text to type.")
            return

        self._stop_event.clear()
        self._is_running = True

        def _run_with_delay() -> None:
            if delay_seconds > 0:
                # Countdown via status updates
                for remaining in range(int(delay_seconds), 0, -1):
                    if self._stop_event.is_set():
                        self._emit_status("Stopped.")
                        self._is_running = False
                        return
                    self._emit_status(f"Starting in {remaining}...")
                    if self._stop_event.wait(1.0):
                        self._emit_status("Stopped.")
                        self._is_running = False
                        return
            self._run_typing()

        self._thread = threading.Thread(target=_run_with_delay, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        """Stop typing immediately."""
        self._stop_event.set()
        self._is_running = False
