"""
TypeFlow Application
Main Gtk.Application subclass that manages app lifecycle.
"""

import logging
from typing import Optional

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, Gio

from . import __app_id__, __app_name__, __version__
from .window import TypeFlowWindow

logger = logging.getLogger(__name__)


class TypeFlowApplication(Adw.Application):
    """
    Main application class for TypeFlow.
    Handles app lifecycle, actions, and window management.
    """

    def __init__(self) -> None:
        super().__init__(
            application_id=__app_id__,
            flags=Gio.ApplicationFlags.DEFAULT_FLAGS,
        )

        # Set up application metadata
        self.set_application_id(__app_id__)

        # Connect signals
        self.connect('activate', self._on_activate)
        self.connect('startup', self._on_startup)
        self.connect('shutdown', self._on_shutdown)

        self._window: Optional[TypeFlowWindow] = None

    def _on_startup(self, app: 'TypeFlowApplication') -> None:
        """Called once when app starts — set up actions and menus."""
        self._setup_actions()
        self._setup_styles()

    def _setup_styles(self) -> None:
        """Apply any custom CSS overrides on top of Adwaita."""
        css_provider = Gtk.CssProvider()
        css = """
        .typeflow-text-area {
            font-size: 14px;
            font-family: monospace;
            padding: 8px;
            border-radius: 8px;
        }

        .typeflow-status-label {
            font-size: 13px;
        }

        .typeflow-progress-bar {
            border-radius: 6px;
        }
        """
        css_provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_display(
            self.get_default_display() if hasattr(self, 'get_default_display') else
            Gtk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def _setup_actions(self) -> None:
        """Set up application-level GActions."""
        # About action
        about_action = Gio.SimpleAction.new('about', None)
        about_action.connect('activate', self._on_about)
        self.add_action(about_action)

        # Quit action
        quit_action = Gio.SimpleAction.new('quit', None)
        quit_action.connect('activate', self._on_quit)
        self.add_action(quit_action)
        self.set_accels_for_action('app.quit', ['<primary>q'])

        # Keyboard shortcut: Ctrl+Q to quit
        self.set_accels_for_action('app.about', [])

    def _on_activate(self, app: 'TypeFlowApplication') -> None:
        """Called when the application is activated (e.g. first launch or re-launch)."""
        if self._window is None:
            self._window = TypeFlowWindow(application=self)

        self._window.present()

    def _on_about(self, action: Gio.SimpleAction, param: None) -> None:
        """Show the About dialog."""
        about = Adw.AboutWindow(
            transient_for=self._window,
            application_name=__app_name__,
            application_icon='com.typeflow.app',
            version=__version__,
            developer_name='TypeFlow Contributors',
            license_type=Gtk.License.MIT_X11,
            comments='Simulate natural human typing into any application.\n'
                     'Paste text, set your WPM, and let TypeFlow do the rest.',
            website='https://github.com/typeflow/typeflow',
            issue_url='https://github.com/typeflow/typeflow/issues',
            copyright='© 2024 TypeFlow Contributors',
        )
        about.present()

    def _on_quit(self, action: Gio.SimpleAction, param: None) -> None:
        """Quit the application."""
        if self._window:
            self._window.cleanup()
        self.quit()

    def _on_shutdown(self, app: 'TypeFlowApplication') -> None:
        """Called when the application is shutting down."""
        if self._window:
            self._window.cleanup()
