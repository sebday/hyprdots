"""Hot-reload Omarchy libadwaita palette in Nautilus when gtk-css-apply.sh sends SIGUSR1."""

import signal
from pathlib import Path

from gi import require_version

require_version("Nautilus", "4.1")
require_version("Gtk", "4.0")
require_version("Gdk", "4.0")
require_version("GLibUnix", "2.0")

from gi.repository import Gdk, GLib, GObject, Gtk, GLibUnix, Nautilus

PALETTE_CSS = (
	Path.home() / ".local/state/omarchy/current/theme/libadwaita-gtk.css"
)
# Above GTK's built-in USER gtk.css provider (800) and libadwaita palette reload.
STYLE_PRIORITY = 10_001


class OmarchyGtkReloader(GObject.GObject, Nautilus.MenuProvider):
	_instance = None
	_provider = None
	_reload_scheduled = False

	@classmethod
	def ensure(cls) -> "OmarchyGtkReloader":
		if cls._instance is None:
			cls._instance = cls()
		return cls._instance

	def __init__(self):
		super().__init__()
		GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, self._on_signal)

	def _on_signal(self, *_args) -> bool:
		self._schedule_reload()
		return True

	def _schedule_reload(self) -> None:
		if self._reload_scheduled:
			return
		self._reload_scheduled = True
		GLib.idle_add(self._reload_css_idle, priority=GLib.PRIORITY_HIGH)

	def _reload_css_idle(self) -> bool:
		self._reload_scheduled = False
		self._reload_css()
		return False

	def _read_palette(self) -> str | None:
		try:
			return PALETTE_CSS.read_text(encoding="utf-8")
		except OSError:
			return None

	def _reload_css(self) -> None:
		display = Gdk.Display.get_default()
		css_text = self._read_palette()
		if display is None or not css_text:
			return

		if self._provider is None:
			self._provider = Gtk.CssProvider()
			Gtk.StyleContext.add_provider_for_display(
				display,
				self._provider,
				STYLE_PRIORITY,
			)

		try:
			self._provider.load_from_string(css_text)
		except GLib.GError:
			pass

	def get_file_items(self, _files):
		return []

	def get_background_items(self, _current_folder):
		return []


OmarchyGtkReloader.ensure()
