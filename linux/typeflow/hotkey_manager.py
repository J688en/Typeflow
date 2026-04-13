"""
TypeFlow Hotkey Manager
Manages global keyboard shortcuts using pynput (works on both X11 and Wayland).
Hotkeys run in a separate thread and communicate with the main app via callbacks.
"""

import threading
import logging
from typing import Callable, Optional

logger = logging.getLogger(__name__)

# Try to import pynput; gracefully degrade if not available
try:
    from pynput import keyboard as pynput_keyboard
    PYNPUT_AVAILABLE = True
except ImportError:
    PYNPUT_AVAILABLE = False
    logger.warning("pynput not available; global hotkeys disabled.")


class HotkeyManager:
    """
    Manages global hotkeys for TypeFlow:
      - Ctrl+Shift+T : Start typing
      - Ctrl+Shift+S : Stop typing
      - Escape        : Emergency stop

    Uses pynput which supports both X11 and Wayland (via uinput on Wayland).
    """

    def __init__(
        self,
        on_start: Optional[Callable[[], None]] = None,
        on_stop: Optional[Callable[[], None]] = None,
    ) -> None:
        """
        Initialize the hotkey manager.

        Args:
            on_start: Callback to invoke when the Start hotkey is pressed.
            on_stop:  Callback to invoke when the Stop hotkey is pressed.
        """
        self.on_start = on_start
        self.on_stop = on_stop
        self._listener: Optional[object] = None
        self._active = False
        self._lock = threading.Lock()

        # Track currently pressed keys
        self._pressed: set = set()

        # Define hotkey combinations
        self._START_COMBO = frozenset([
            'ctrl', 'shift', 't'
        ])
        self._STOP_COMBO = frozenset([
            'ctrl', 'shift', 's'
        ])

    def _key_name(self, key) -> Optional[str]:
        """Extract a normalized key name from a pynput key object."""
        if not PYNPUT_AVAILABLE:
            return None
        try:
            # Special keys
            if key == pynput_keyboard.Key.esc:
                return 'escape'
            if key == pynput_keyboard.Key.ctrl_l or key == pynput_keyboard.Key.ctrl_r:
                return 'ctrl'
            if key == pynput_keyboard.Key.shift or key == pynput_keyboard.Key.shift_r:
                return 'shift'
            if key == pynput_keyboard.Key.alt_l or key == pynput_keyboard.Key.alt_r:
                return 'alt'
            # Regular character keys
            if hasattr(key, 'char') and key.char:
                return key.char.lower()
        except Exception:
            pass
        return None

    def _on_press(self, key) -> None:
        """Handle key press events."""
        name = self._key_name(key)
        if name is None:
            return

        with self._lock:
            self._pressed.add(name)
            current = frozenset(self._pressed)

        # Check for Escape (emergency stop)
        if name == 'escape':
            if self.on_stop:
                self.on_stop()
            return

        # Check for start combo: Ctrl+Shift+T
        if self._START_COMBO.issubset(current):
            if self.on_start:
                self.on_start()

        # Check for stop combo: Ctrl+Shift+S
        if self._STOP_COMBO.issubset(current):
            if self.on_stop:
                self.on_stop()

    def _on_release(self, key) -> None:
        """Handle key release events."""
        name = self._key_name(key)
        if name is None:
            return
        with self._lock:
            self._pressed.discard(name)

    def start(self) -> bool:
        """
        Start listening for global hotkeys.
        Returns True if listener started successfully, False if pynput unavailable.
        """
        if not PYNPUT_AVAILABLE:
            logger.warning("pynput not available; cannot start hotkey listener.")
            return False

        if self._active:
            return True

        try:
            self._listener = pynput_keyboard.Listener(
                on_press=self._on_press,
                on_release=self._on_release,
            )
            self._listener.start()
            self._active = True
            logger.info("Hotkey listener started.")
            return True
        except Exception as e:
            logger.error(f"Failed to start hotkey listener: {e}")
            return False

    def stop(self) -> None:
        """Stop listening for global hotkeys."""
        if self._listener and self._active:
            try:
                self._listener.stop()
            except Exception:
                pass
            self._active = False
            self._listener = None
            logger.info("Hotkey listener stopped.")

    @property
    def is_active(self) -> bool:
        """Whether the hotkey listener is currently running."""
        return self._active

    @property
    def is_available(self) -> bool:
        """Whether pynput is available for hotkey support."""
        return PYNPUT_AVAILABLE
