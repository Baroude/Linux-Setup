#!/usr/bin/env python3
"""wallpaper-watcher — zero-overhead event-driven wallpaper-change hook.

Two complementary triggers:

1. org.kde.PlasmaShell.wallpaperChanged D-Bus signal
   Fires when wallpaper-next.sh (or any caller of setWallpaper()) changes
   the wallpaper.

2. Gio.FileMonitor on plasma-org.kde.plasma.desktop-appletsrc
   Catches changes made by Dolphin ("Set as Wallpaper"), System Settings,
   or any tool that writes the config directly without calling setWallpaper().

Both triggers feed into the same 500 ms debounced apply function.
Deduplication via _last_applied_wall prevents double-firing when both
triggers fire for the same wallpaper change.
"""

import os
import re
import subprocess
from urllib.parse import unquote

import dbus
import dbus.mainloop.glib
from gi.repository import Gio, GLib

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
HOOK = os.path.join(REPO_DIR, "scripts", "wallpaper-apply.sh")
APPLETSRC = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")

_pending_timer = None
_last_screen = 0
_plasma_iface = None
_last_applied_wall = ""


def _read_wall_from_appletsrc() -> str:
    """Read the current wallpaper path from the Plasma config file."""
    try:
        with open(APPLETSRC, encoding="utf-8", errors="replace") as f:
            content = f.read()
        m = re.search(r"Image=(?:file://)?([^\n,]+)", content)
        if m:
            return unquote(m.group(1).strip())
    except Exception:
        pass
    return ""


def _do_apply(wall_path: str) -> bool:
    """Run wallpaper-apply.sh, skipping if it's the same wall as last time."""
    global _pending_timer, _last_applied_wall
    _pending_timer = None

    if not wall_path:
        wall_path = _read_wall_from_appletsrc()

    if not wall_path:
        subprocess.Popen(["bash", HOOK])
        return False

    if wall_path == _last_applied_wall:
        return False  # already applied, skip

    _last_applied_wall = wall_path

    if os.path.isfile(wall_path):
        subprocess.Popen(["bash", HOOK, "--wallpaper", wall_path])
    else:
        subprocess.Popen(["bash", HOOK])

    return False  # remove GLib timer


def _schedule_apply(wall_path: str = "") -> None:
    """Cancel any pending apply and schedule a new one after 500 ms."""
    global _pending_timer
    if _pending_timer is not None:
        GLib.source_remove(_pending_timer)
    _pending_timer = GLib.timeout_add(500, _do_apply, wall_path)


# ── Trigger 1: D-Bus wallpaperChanged signal ──────────────────────────────────

def on_wallpaper_changed(screen_num: int) -> None:
    global _last_screen
    _last_screen = int(screen_num)

    wall_path = ""
    try:
        config = _plasma_iface.wallpaper(_last_screen)
        raw = str(config.get("Image", ""))
        if raw.startswith("file://"):
            wall_path = unquote(raw[7:])
        elif raw:
            wall_path = raw
    except Exception:
        pass

    _schedule_apply(wall_path)


# ── Trigger 2: Gio file monitor on appletsrc ──────────────────────────────────

def on_appletsrc_changed(
    monitor, file, other_file, event_type  # noqa: ARG001
) -> None:
    if event_type in (
        Gio.FileMonitorEvent.CHANGED,
        Gio.FileMonitorEvent.CHANGES_DONE_HINT,
        Gio.FileMonitorEvent.CREATED,
    ):
        # Read the new path immediately; debounce handles rapid writes
        _schedule_apply(_read_wall_from_appletsrc())


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

    # File monitor — catches Dolphin / System Settings changes
    gfile = Gio.File.new_for_path(APPLETSRC)
    monitor = gfile.monitor_file(Gio.FileMonitorFlags.NONE, None)
    monitor.connect("changed", on_appletsrc_changed)

    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
