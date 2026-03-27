#!/usr/bin/env python3
"""wallpaper-watcher — zero-overhead event-driven wallpaper-change hook.

Subscribes to the org.kde.PlasmaShell.wallpaperChanged D-Bus signal and
calls wallpaper-apply.sh on every change.  Covers both:
  • automated rotation  (wallpaper-next.sh → setWallpaper D-Bus method)
  • manual changes      (System Settings → internally calls setWallpaper)

The signal only fires when setWallpaper() is used (not evaluateScript),
so wallpaper-next.sh must use setWallpaper — which is the case here.

A 300 ms debounce collapses rapid multi-screen signals into one apply run.
"""

import os
import subprocess
import sys
from urllib.parse import unquote

import dbus
import dbus.mainloop.glib
from gi.repository import GLib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
HOOK = os.path.join(REPO_DIR, "scripts", "wallpaper-apply.sh")

_pending_timer = None
_last_screen = 0
_plasma_iface = None


def _do_apply(screen_num: int) -> bool:
    global _pending_timer
    _pending_timer = None

    wall_path = ""
    try:
        config = _plasma_iface.wallpaper(screen_num)
        raw = str(config.get("Image", ""))
        if raw.startswith("file://"):
            wall_path = unquote(raw[7:])
        elif raw:
            wall_path = raw
    except Exception:
        pass

    if wall_path and os.path.isfile(wall_path):
        subprocess.Popen(["bash", HOOK, "--wallpaper", wall_path])
    else:
        # Fallback: let wallpaper-apply.sh read the path from plasma config
        subprocess.Popen(["bash", HOOK])

    return False  # remove GLib timer


def on_wallpaper_changed(screen_num: int) -> None:
    global _pending_timer, _last_screen
    _last_screen = int(screen_num)
    if _pending_timer is not None:
        GLib.source_remove(_pending_timer)
    _pending_timer = GLib.timeout_add(300, _do_apply, _last_screen)


def main() -> None:
    global _plasma_iface

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()

    _plasma_iface = dbus.Interface(
        bus.get_object("org.kde.plasmashell", "/PlasmaShell"),
        "org.kde.PlasmaShell",
    )

    bus.add_signal_receiver(
        on_wallpaper_changed,
        signal_name="wallpaperChanged",
        dbus_interface="org.kde.PlasmaShell",
        path="/PlasmaShell",
    )

    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
