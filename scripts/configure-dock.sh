#!/usr/bin/env bash
# configure-dock.sh — Plasma 6 panel layout via JS scripting API
# Creates:
#   Bottom dock  (floating pill): Kickoff | icontasks [pinned: Kitty/Dolphin/Firefox/Tidal] | Spacer | Trash
#   Top bar      (full-width):    AppMenu | Spacer | Media | SysMonitor | SysTray | Clock
#
# Requires a running plasmashell session.
# Called from setup.sh Phase 9 — safe to re-run.

set -euo pipefail

# Support both qdbus6 and qdbus (distro differences)
DBUS_CMD="qdbus6"
command -v qdbus6 &>/dev/null || DBUS_CMD="qdbus"

# ---------------------------------------------------------------------------
# Evaluate the layout via Plasma JS scripting API
# ---------------------------------------------------------------------------
$DBUS_CMD org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '

// ── Remove existing bottom and top panels ──────────────────────────────────
panelIds.forEach(function(id) {
    var p = panelById(id);
    if (!p) return;
    if (p.location === "bottom" || p.location === "top") {
        p.remove();
    }
});

// ── Bottom dock ────────────────────────────────────────────────────────────
// lengthMode = "fit"  → dock shrinks/grows to fit content (pill-dock style)
// floating is set afterwards via kwriteconfig6 (not writable via JS API)
var dock = new Panel;
dock.location   = "bottom";
dock.height     = 56;
dock.alignment  = "center";
dock.lengthMode = "fit";

// App Launcher (Kickoff)
dock.addWidget("org.kde.plasma.kickoff");

// Icons-only Task Manager — pinned launchers show even when apps are closed
var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
    "applications:kitty.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop",
    "applications:com.mastermindzh.tidal-hifi.desktop"
].join(","));
tasks.writeConfig("showOnlyCurrentDesktop", "false");

// Spacer + Trash at the right edge of the dock
dock.addWidget("org.kde.plasma.panelspacer");
dock.addWidget("org.kde.plasma.trash");

// ── Top bar ────────────────────────────────────────────────────────────────
// lengthMode = "fill" → spans full screen width
var top = new Panel;
top.location   = "top";
top.height     = 36;
top.alignment  = "center";
top.lengthMode = "fill";

// Global menu — shows active Qt/GTK app menu bar in the panel
top.addWidget("org.kde.plasma.appmenu");

// Spacer pushes all right-side widgets to the right
top.addWidget("org.kde.plasma.panelspacer");

// MPRIS media control (Tidal, Spotify, etc.)
top.addWidget("org.kde.plasma.mediacontroller");

// System resource monitor (CPU/RAM graphs)
top.addWidget("org.kde.plasma.systemmonitor");

// System tray (notifications, network, Bluetooth, volume …)
top.addWidget("org.kde.plasma.systemtray");

// Digital clock with date
var clock = top.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Configuration", "Appearance"];
clock.writeConfig("showDate", "true");
clock.writeConfig("dateDisplayFormat", "BelowTime");
clock.writeConfig("dateFormat", "shortDate");

'

# ---------------------------------------------------------------------------
# Enable floating mode on the bottom dock
# (the JS API cannot write this — must use kwriteconfig6 on the config file)
# ---------------------------------------------------------------------------
DOCK_ID=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    'var bottom = panelIds.filter(function(id){ return panelById(id) && panelById(id).location === "bottom"; }); print(bottom[bottom.length-1]);' \
    2>/dev/null | tail -1)

if [[ -n "${DOCK_ID:-}" && "$DOCK_ID" =~ ^[0-9]+$ ]]; then
    kwriteconfig6 \
        --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group "Containments" --group "$DOCK_ID" \
        --group "Configuration" --group "General" \
        --key "floating" "1"

    # Signal plasmashell to re-read this containment's config
    $DBUS_CMD org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "var p = panelById(${DOCK_ID}); if(p) p.reloadConfig();" 2>/dev/null || true

    echo "Floating mode applied to dock containment ${DOCK_ID}"
fi
