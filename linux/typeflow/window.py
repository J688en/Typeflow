"""
TypeFlow Main Window
Full GTK4/libadwaita UI for the TypeFlow application.
Follows GNOME Human Interface Guidelines with Adwaita styling.
"""

import logging

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gio, Pango

from .typing_engine import TypingEngine
from .hotkey_manager import HotkeyManager

logger = logging.getLogger(__name__)

# Countdown seconds before typing starts
COUNTDOWN_SECONDS = 5


class TypeFlowWindow(Adw.ApplicationWindow):
    """
    Main application window for TypeFlow.

    Layout:
      - Adw.HeaderBar with title and menu button
      - Adw.Clamp limiting content width
        - Text input area (ScrolledWindow + TextView)
        - Character/word count label
        - Settings group (WPM slider, typo toggle, start method)
        - Control buttons (Start/Stop)
        - Status area (progress bar + status label)
    """

    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs)

        self.set_title("TypeFlow")
        self.set_default_size(520, 680)
        self.set_resizable(True)

        # Core components
        self._engine = TypingEngine(
            on_progress=self._on_typing_progress,
            on_finished=self._on_typing_finished,
            on_error=self._on_typing_error,
            on_status=self._on_typing_status,
        )

        self._hotkey_manager = HotkeyManager(
            on_start=self._hotkey_start_triggered,
            on_stop=self._hotkey_stop_triggered,
        )

        # UI state
        self._is_typing = False
        self._hotkey_mode = False  # True = hotkey mode, False = countdown mode

        self._build_ui()
        self._start_hotkey_listener()

    # ─────────────────────────────────────────────
    # UI Construction
    # ─────────────────────────────────────────────

    def _build_ui(self) -> None:
        """Construct the complete window UI."""
        # Root content box
        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(content_box)

        # Header bar
        header_bar = self._build_header_bar()
        content_box.append(header_bar)

        # Scrollable main area
        scroll = Gtk.ScrolledWindow()
        scroll.set_vexpand(True)
        scroll.set_hexpand(True)
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        content_box.append(scroll)

        # Clamp for content width
        clamp = Adw.Clamp()
        clamp.set_maximum_size(600)
        clamp.set_tightening_threshold(500)
        scroll.set_child(clamp)

        # Main vertical layout inside clamp
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        main_box.set_margin_top(16)
        main_box.set_margin_bottom(24)
        main_box.set_margin_start(16)
        main_box.set_margin_end(16)
        clamp.set_child(main_box)

        # ── Text Input Section ──
        main_box.append(self._build_text_section())

        # ── Word/Char Count Row ──
        main_box.append(self._build_count_row())

        # ── Settings Group ──
        main_box.append(self._build_settings_group())

        # ── Start Method Group ──
        main_box.append(self._build_start_method_group())

        # ── Controls Row ──
        main_box.append(self._build_controls_row())

        # ── Status / Progress Section ──
        main_box.append(self._build_status_section())

        # ── Backend Info Row ──
        main_box.append(self._build_backend_info())

    def _build_header_bar(self) -> Adw.HeaderBar:
        """Build the Adwaita header bar."""
        header_bar = Adw.HeaderBar()

        # Title with subtitle
        title_widget = Adw.WindowTitle(
            title="TypeFlow",
            subtitle="Natural Typing Simulator"
        )
        header_bar.set_title_widget(title_widget)

        # Menu button
        menu_button = Gtk.MenuButton()
        menu_button.set_icon_name("open-menu-symbolic")
        menu_button.set_tooltip_text("Main Menu")

        # Build menu
        menu = Gio.Menu()
        menu.append("About TypeFlow", "app.about")
        menu.append("Quit", "app.quit")
        menu_button.set_menu_model(menu)
        header_bar.pack_end(menu_button)

        return header_bar

    def _build_text_section(self) -> Gtk.Box:
        """Build the text input area with label."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)

        # Section label
        label = Gtk.Label(label="Text to Type", xalign=0)
        label.add_css_class("heading")
        box.append(label)

        # Subtitle
        sub = Gtk.Label(
            label="Paste or type the text you want TypeFlow to simulate",
            xalign=0
        )
        sub.add_css_class("dim-label")
        sub.add_css_class("caption")
        sub.set_wrap(True)
        box.append(sub)

        # Rounded frame containing the text view
        frame = Gtk.Frame()
        frame.add_css_class("card")
        box.append(frame)

        # Scrolled window for text view
        scroll = Gtk.ScrolledWindow()
        scroll.set_min_content_height(160)
        scroll.set_max_content_height(260)
        scroll.set_vexpand(False)
        scroll.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        frame.set_child(scroll)

        # Text view
        self._text_view = Gtk.TextView()
        self._text_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self._text_view.add_css_class("typeflow-text-area")
        self._text_view.set_top_margin(10)
        self._text_view.set_bottom_margin(10)
        self._text_view.set_left_margin(12)
        self._text_view.set_right_margin(12)

        # Placeholder text via tag
        self._text_buffer = self._text_view.get_buffer()
        self._text_buffer.set_text("")
        self._text_buffer.connect('changed', self._on_text_changed)

        # Placeholder hint (inserted as initial text)
        placeholder_tag = self._text_buffer.create_tag(
            'placeholder',
            foreground='gray',
            style=Pango.Style.ITALIC
        )
        self._showing_placeholder = True
        self._text_buffer.insert_with_tags(
            self._text_buffer.get_end_iter(),
            "Paste or type your text here...",
            placeholder_tag
        )

        scroll.set_child(self._text_view)

        # Connect focus signals for placeholder behavior
        focus_ctrl = Gtk.EventControllerFocus()
        focus_ctrl.connect('enter', self._on_text_focus_in)
        focus_ctrl.connect('leave', self._on_text_focus_out)
        self._text_view.add_controller(focus_ctrl)

        return box

    def _build_count_row(self) -> Gtk.Box:
        """Build the character/word count display row."""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)

        self._char_count_label = Gtk.Label(label="0 characters")
        self._char_count_label.add_css_class("dim-label")
        self._char_count_label.add_css_class("caption")

        self._word_count_label = Gtk.Label(label="0 words")
        self._word_count_label.add_css_class("dim-label")
        self._word_count_label.add_css_class("caption")

        box.append(self._char_count_label)

        sep = Gtk.Label(label="·")
        sep.add_css_class("dim-label")
        sep.add_css_class("caption")
        box.append(sep)

        box.append(self._word_count_label)

        return box

    def _build_settings_group(self) -> Adw.PreferencesGroup:
        """Build the typing settings preferences group."""
        group = Adw.PreferencesGroup()
        group.set_title("Typing Settings")
        group.set_description("Adjust speed and behavior")

        # WPM Row with slider
        wpm_row = Adw.ActionRow()
        wpm_row.set_title("Typing Speed")
        wpm_row.set_subtitle("Words per minute")

        wpm_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        wpm_box.set_valign(Gtk.Align.CENTER)

        self._wpm_label = Gtk.Label(label="60 WPM")
        self._wpm_label.set_width_chars(8)
        self._wpm_label.add_css_class("numeric")

        self._wpm_slider = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 30, 120, 5
        )
        self._wpm_slider.set_value(60)
        self._wpm_slider.set_draw_value(False)
        self._wpm_slider.set_hexpand(True)
        self._wpm_slider.set_size_request(160, -1)
        self._wpm_slider.connect('value-changed', self._on_wpm_changed)

        # Add tick marks
        self._wpm_slider.add_mark(30, Gtk.PositionType.BOTTOM, "30")
        self._wpm_slider.add_mark(60, Gtk.PositionType.BOTTOM, "60")
        self._wpm_slider.add_mark(90, Gtk.PositionType.BOTTOM, "90")
        self._wpm_slider.add_mark(120, Gtk.PositionType.BOTTOM, "120")

        wpm_box.append(self._wpm_slider)
        wpm_box.append(self._wpm_label)
        wpm_row.add_suffix(wpm_box)
        group.add(wpm_row)

        # Typo simulation toggle row
        typo_row = Adw.ActionRow()
        typo_row.set_title("Typo Simulation")
        typo_row.set_subtitle("Randomly mistype and auto-correct (~4% of characters)")

        self._typo_switch = Gtk.Switch()
        self._typo_switch.set_active(True)
        self._typo_switch.set_valign(Gtk.Align.CENTER)
        self._typo_switch.connect('notify::active', self._on_typo_toggled)
        typo_row.add_suffix(self._typo_switch)
        typo_row.set_activatable_widget(self._typo_switch)
        group.add(typo_row)

        return group

    def _build_start_method_group(self) -> Adw.PreferencesGroup:
        """Build the start method selection group."""
        group = Adw.PreferencesGroup()
        group.set_title("Start Method")
        group.set_description("How TypeFlow begins typing after you click Start")

        # Countdown row
        self._countdown_row = Adw.ActionRow()
        self._countdown_row.set_title("Countdown Timer")
        self._countdown_row.set_subtitle(
            "5-second countdown, then types at current cursor position"
        )

        self._start_method_group_check = Gtk.CheckButton()
        self._start_method_group_check.set_active(True)
        self._start_method_group_check.set_valign(Gtk.Align.CENTER)
        self._countdown_row.add_prefix(self._start_method_group_check)
        self._countdown_row.set_activatable_widget(self._start_method_group_check)
        group.add(self._countdown_row)

        # Hotkey row
        hotkey_row = Adw.ActionRow()
        hotkey_row.set_title("Global Hotkey")
        hotkey_row.set_subtitle(
            "Press Ctrl+Shift+T to start typing at current cursor position"
        )

        self._hotkey_check = Gtk.CheckButton()
        self._hotkey_check.set_group(self._start_method_group_check)
        self._hotkey_check.set_valign(Gtk.Align.CENTER)
        self._hotkey_check.connect('notify::active', self._on_start_method_changed)
        hotkey_row.add_prefix(self._hotkey_check)
        hotkey_row.set_activatable_widget(self._hotkey_check)
        group.add(hotkey_row)

        # Hotkey availability warning
        if not self._hotkey_manager.is_available:
            warning_row = Adw.ActionRow()
            warning_row.set_title("pynput not installed")
            warning_row.set_subtitle(
                "Install pynput for global hotkey support: pip install pynput"
            )
            warning_icon = Gtk.Image.new_from_icon_name("dialog-warning-symbolic")
            warning_icon.add_css_class("warning")
            warning_row.add_prefix(warning_icon)
            group.add(warning_row)

        return group

    def _build_controls_row(self) -> Gtk.Box:
        """Build the Start/Stop control buttons."""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_halign(Gtk.Align.CENTER)

        # Start button
        self._start_button = Gtk.Button()
        self._start_button.set_size_request(160, 42)
        self._update_start_button_label()
        self._start_button.add_css_class("suggested-action")
        self._start_button.add_css_class("pill")
        self._start_button.connect('clicked', self._on_start_clicked)

        # Stop button
        self._stop_button = Gtk.Button(label="Stop")
        self._stop_button.set_size_request(100, 42)
        self._stop_button.add_css_class("destructive-action")
        self._stop_button.add_css_class("pill")
        self._stop_button.set_sensitive(False)
        self._stop_button.connect('clicked', self._on_stop_clicked)

        # Stop key hint
        stop_hint = Gtk.Label(label="or press Esc / Ctrl+Shift+S")
        stop_hint.add_css_class("dim-label")
        stop_hint.add_css_class("caption")

        inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        inner.set_halign(Gtk.Align.CENTER)

        btn_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_row.set_halign(Gtk.Align.CENTER)
        btn_row.append(self._start_button)
        btn_row.append(self._stop_button)

        inner.append(btn_row)
        inner.append(stop_hint)
        box.append(inner)

        return box

    def _build_status_section(self) -> Gtk.Box:
        """Build the status section with progress bar and status label."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)

        # Progress bar
        self._progress_bar = Gtk.ProgressBar()
        self._progress_bar.set_fraction(0.0)
        self._progress_bar.add_css_class("typeflow-progress-bar")
        self._progress_bar.set_show_text(True)
        self._progress_bar.set_text("Ready")
        box.append(self._progress_bar)

        # Status label
        self._status_label = Gtk.Label(label="")
        self._status_label.add_css_class("dim-label")
        self._status_label.add_css_class("typeflow-status-label")
        self._status_label.set_wrap(True)
        self._status_label.set_halign(Gtk.Align.CENTER)
        box.append(self._status_label)

        return box

    def _build_backend_info(self) -> Gtk.Box:
        """Build the typing backend info row at the bottom."""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        box.set_halign(Gtk.Align.CENTER)
        box.set_margin_top(4)

        backend = self._engine.backend
        icon_name = "emblem-ok-symbolic" if backend.is_available else "dialog-warning-symbolic"
        icon = Gtk.Image.new_from_icon_name(icon_name)
        icon.add_css_class("dim-label")

        text = f"Backend: {backend.backend_name}"
        lbl = Gtk.Label(label=text)
        lbl.add_css_class("dim-label")
        lbl.add_css_class("caption")

        box.append(icon)
        box.append(lbl)

        if not backend.is_available:
            install_lbl = Gtk.Label(
                label=" — Install xdotool: sudo apt install xdotool"
            )
            install_lbl.add_css_class("caption")
            install_lbl.add_css_class("error")
            box.append(install_lbl)

        return box

    # ─────────────────────────────────────────────
    # Placeholder Text Logic
    # ─────────────────────────────────────────────

    def _on_text_focus_in(self, controller: Gtk.EventControllerFocus) -> None:
        """Remove placeholder text when user focuses the text area."""
        if self._showing_placeholder:
            self._showing_placeholder = False
            self._text_buffer.disconnect_by_func(self._on_text_changed)
            self._text_buffer.set_text("")
            self._text_buffer.connect('changed', self._on_text_changed)
            self._update_counts()

    def _on_text_focus_out(self, controller: Gtk.EventControllerFocus) -> None:
        """Restore placeholder text if text area is empty."""
        start = self._text_buffer.get_start_iter()
        end = self._text_buffer.get_end_iter()
        text = self._text_buffer.get_text(start, end, False)
        if not text.strip():
            self._showing_placeholder = True
            self._text_buffer.disconnect_by_func(self._on_text_changed)
            placeholder_tag = self._text_buffer.get_tag_table().lookup('placeholder')
            if not placeholder_tag:
                placeholder_tag = self._text_buffer.create_tag(
                    'placeholder',
                    foreground='gray',
                    style=Pango.Style.ITALIC
                )
            self._text_buffer.set_text("")
            self._text_buffer.insert_with_tags(
                self._text_buffer.get_end_iter(),
                "Paste or type your text here...",
                placeholder_tag
            )
            self._text_buffer.connect('changed', self._on_text_changed)
            self._update_counts()

    # ─────────────────────────────────────────────
    # Event Handlers
    # ─────────────────────────────────────────────

    def _on_text_changed(self, buffer: Gtk.TextBuffer) -> None:
        """Handle text buffer changes — update counts."""
        if not self._showing_placeholder:
            self._update_counts()

    def _update_counts(self) -> None:
        """Update the character and word count labels."""
        text = self._get_text()
        char_count = len(text)
        word_count = len(text.split()) if text.strip() else 0

        char_label = f"{char_count:,} character{'s' if char_count != 1 else ''}"
        word_label = f"{word_count:,} word{'s' if word_count != 1 else ''}"

        self._char_count_label.set_label(char_label)
        self._word_count_label.set_label(word_label)

    def _get_text(self) -> str:
        """Get the actual text from the buffer (excluding placeholder)."""
        if self._showing_placeholder:
            return ""
        start = self._text_buffer.get_start_iter()
        end = self._text_buffer.get_end_iter()
        return self._text_buffer.get_text(start, end, False)

    def _on_wpm_changed(self, scale: Gtk.Scale) -> None:
        """Update WPM label when slider moves."""
        value = int(scale.get_value())
        self._wpm_label.set_label(f"{value} WPM")
        self._engine.wpm = value

    def _on_typo_toggled(self, switch: Gtk.Switch, _param) -> None:
        """Toggle typo simulation."""
        self._engine.typo_enabled = switch.get_active()

    def _on_start_method_changed(self, check: Gtk.CheckButton, _param) -> None:
        """Update start method when radio button changes."""
        # _hotkey_check active means hotkey mode
        self._hotkey_mode = check.get_active()
        self._update_start_button_label()

    def _update_start_button_label(self) -> None:
        """Update Start button label based on selected method."""
        if hasattr(self, '_hotkey_mode') and self._hotkey_mode:
            self._start_button.set_label("Arm Hotkey")
        else:
            self._start_button.set_label("Start (5s countdown)")

    def _on_start_clicked(self, button: Gtk.Button) -> None:
        """Handle Start button click."""
        text = self._get_text()
        if not text.strip():
            self._show_error_banner("Please enter some text to type first.")
            return

        self._engine.text = text
        self._engine.wpm = int(self._wpm_slider.get_value())
        self._engine.typo_enabled = self._typo_switch.get_active()

        self._progress_bar.set_fraction(0.0)
        self._progress_bar.set_text("0%")
        self._set_typing_state(True)

        if self._hotkey_mode:
            # Hotkey mode: arm the engine, wait for hotkey
            self._status_label.set_label("Press Ctrl+Shift+T to begin typing")
            self._engine_armed = True
        else:
            # Countdown mode
            self._engine_armed = False
            self._engine.start(delay_seconds=float(COUNTDOWN_SECONDS))

    def _on_stop_clicked(self, button: Gtk.Button) -> None:
        """Handle Stop button click."""
        self._stop_typing()

    def _stop_typing(self) -> None:
        """Stop the typing engine and reset UI state."""
        self._engine.stop()
        self._engine_armed = False
        self._set_typing_state(False)

    def _set_typing_state(self, is_active: bool) -> None:
        """Enable/disable UI elements based on typing state."""
        self._is_typing = is_active
        self._start_button.set_sensitive(not is_active)
        self._stop_button.set_sensitive(is_active)
        self._text_view.set_editable(not is_active)
        self._wpm_slider.set_sensitive(not is_active)
        self._typo_switch.set_sensitive(not is_active)

    # ─────────────────────────────────────────────
    # Hotkey Callbacks (called from background thread)
    # ─────────────────────────────────────────────

    def _hotkey_start_triggered(self) -> None:
        """Called when Ctrl+Shift+T is pressed globally."""
        # Don't check is_armed here since GLib.idle_add handles thread safety
        GLib.idle_add(self._on_hotkey_start)

    def _hotkey_stop_triggered(self) -> None:
        """Called when Escape or Ctrl+Shift+S is pressed globally."""
        GLib.idle_add(self._on_hotkey_stop)

    def _on_hotkey_start(self) -> bool:
        """GTK-thread handler for global start hotkey."""
        if hasattr(self, '_engine_armed') and self._engine_armed:
            self._engine_armed = False
            self._engine.start(delay_seconds=0.0)
        elif not self._is_typing and self._hotkey_mode:
            # Auto-start if text is ready
            text = self._get_text()
            if text.strip():
                self._engine.text = text
                self._engine.wpm = int(self._wpm_slider.get_value())
                self._engine.typo_enabled = self._typo_switch.get_active()
                self._progress_bar.set_fraction(0.0)
                self._set_typing_state(True)
                self._engine.start(delay_seconds=0.0)
        return GLib.SOURCE_REMOVE

    def _on_hotkey_stop(self) -> bool:
        """GTK-thread handler for global stop hotkey."""
        if self._is_typing:
            self._stop_typing()
        return GLib.SOURCE_REMOVE

    # ─────────────────────────────────────────────
    # Engine Callbacks (already marshalled via GLib.idle_add)
    # ─────────────────────────────────────────────

    def _on_typing_progress(self, typed: int, total: int) -> None:
        """Update progress bar as typing proceeds."""
        if total > 0:
            fraction = typed / total
            self._progress_bar.set_fraction(fraction)
            self._progress_bar.set_text(f"{int(fraction * 100)}%  ({typed}/{total} chars)")

    def _on_typing_finished(self) -> None:
        """Handle typing completion."""
        self._set_typing_state(False)
        self._progress_bar.set_fraction(1.0)
        self._progress_bar.set_text("Complete!")
        self._status_label.set_label("Typing finished successfully.")

    def _on_typing_error(self, message: str) -> None:
        """Handle typing engine errors."""
        self._set_typing_state(False)
        self._show_error_dialog(message)
        self._status_label.set_label("Error occurred.")

    def _on_typing_status(self, message: str) -> None:
        """Update the status label with engine status messages."""
        self._status_label.set_label(message)

    # ─────────────────────────────────────────────
    # Dialogs & Banners
    # ─────────────────────────────────────────────

    def _show_error_banner(self, message: str) -> None:
        """Show a brief in-window error notification using Adw.Toast."""
        toast = Adw.Toast.new(message)
        toast.set_timeout(4)
        # Get the toast overlay if we have one, otherwise use a dialog
        self._show_toast(toast)

    def _show_toast(self, toast: Adw.Toast) -> None:
        """Show a toast notification — creates a transient dialog fallback."""
        # Use simple dialog as fallback (ToastOverlay requires wrapping)
        dialog = Adw.MessageDialog.new(self, "Notice", toast.get_title())
        dialog.add_response("ok", "OK")
        dialog.set_default_response("ok")
        dialog.connect("response", lambda d, _: d.destroy())
        dialog.present()

    def _show_error_dialog(self, message: str) -> None:
        """Show an error dialog."""
        dialog = Adw.MessageDialog.new(
            self,
            "TypeFlow Error",
            message
        )
        dialog.add_response("ok", "OK")
        dialog.set_default_response("ok")
        dialog.set_response_appearance("ok", Adw.ResponseAppearance.DEFAULT)
        dialog.connect("response", lambda d, _: d.destroy())
        dialog.present()

    # ─────────────────────────────────────────────
    # Lifecycle
    # ─────────────────────────────────────────────

    def _start_hotkey_listener(self) -> None:
        """Start global hotkey listener if pynput is available."""
        started = self._hotkey_manager.start()
        if not started:
            logger.info("Global hotkeys not available (pynput missing or no permission).")

    def cleanup(self) -> None:
        """Clean up resources on window close."""
        self._engine.stop()
        self._hotkey_manager.stop()
