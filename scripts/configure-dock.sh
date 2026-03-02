#!/usr/bin/env bash
# configure-dock.sh — Plasma 6 panel layout via JS scripting API
# Creates:
#   Bottom dock (floating pill): Kickoff | icontasks [pinned apps] | Spacer | Trash
#   Top bar     (full-width):    AppMenu | Spacer | Media | SysMonitor | SysTray | Clock
#
# Requires a running plasmashell session. Safe to re-run.

set -euo pipefail

DBUS_CMD="qdbus6"
command -v qdbus6 &>/dev/null || DBUS_CMD="qdbus"

# catppuccin-vibes SVG icons (downloaded by setup.sh Phase 6)
VIBES_DIR="$HOME/.local/share/icons/catppuccin-vibes"

# ── Detect .desktop file names (vary between distros) ──────────────────────

# Firefox: Debian ships firefox-esr.desktop, not firefox.desktop
FIREFOX_DESKTOP="firefox.desktop"
if [[ ! -f /usr/share/applications/firefox.desktop ]] && \
   [[ -f /usr/share/applications/firefox-esr.desktop ]]; then
  FIREFOX_DESKTOP="firefox-esr.desktop"
fi

# Build pinned launcher list
LAUNCHERS="applications:kitty.desktop"
LAUNCHERS="${LAUNCHERS},applications:org.kde.dolphin.desktop"
LAUNCHERS="${LAUNCHERS},applications:${FIREFOX_DESKTOP}"

# Add tidal-hifi only if it's installed (Flatpak)
if flatpak list --app 2>/dev/null | grep -q "com.mastermindzh.tidal-hifi"; then
  LAUNCHERS="${LAUNCHERS},applications:com.mastermindzh.tidal-hifi.desktop"
fi

echo "Launchers: ${LAUNCHERS}"

# ── Apply panel layout via Plasma JS ───────────────────────────────────────
# Double-quoted string so bash variables (LAUNCHERS) expand into the JS.
# JS strings use single quotes to avoid conflict.
$DBUS_CMD org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "

// ── Remove existing bottom and top panels ──
panelIds.forEach(function(id) {
    var p = panelById(id);
    if (!p) return;
    if (p.location === 'bottom' || p.location === 'top') p.remove();
});

// ── Bottom dock ────────────────────────────────────────────────────────────
// lengthMode = 'fit'  → dock shrinks to content (pill style)
// floating applied afterwards via kwriteconfig6 (JS API cannot write it)
var dock = new Panel;
dock.location   = 'bottom';
dock.height     = 56;
dock.alignment  = 'center';
dock.lengthMode = 'fit';

var kickoff = dock.addWidget('org.kde.plasma.kickoff');
kickoff.currentConfigGroup = ['General'];
kickoff.writeConfig('icon', '${VIBES_DIR}/apps-vibrant.svg');

var tasks = dock.addWidget('org.kde.plasma.icontasks');
tasks.currentConfigGroup = ['General'];
tasks.writeConfig('launchers', '${LAUNCHERS}');
tasks.writeConfig('showOnlyCurrentDesktop', 'false');

dock.addWidget('org.kde.plasma.panelspacer');
dock.addWidget('org.kde.plasma.trash');

// ── Top bar ────────────────────────────────────────────────────────────────
var top = new Panel;
top.location   = 'top';
top.height     = 36;
top.alignment  = 'center';
top.lengthMode = 'fill';

top.addWidget('org.kde.plasma.appmenu');
top.addWidget('org.kde.plasma.panelspacer');
top.addWidget('org.kde.plasma.mediacontroller');
top.addWidget('org.kde.plasma.systemmonitor');
top.addWidget('org.kde.plasma.systemtray');

var clock = top.addWidget('org.kde.plasma.digitalclock');
clock.currentConfigGroup = ['Configuration', 'Appearance'];
clock.writeConfig('showDate', 'true');
clock.writeConfig('dateDisplayFormat', 'BelowTime');
clock.writeConfig('dateFormat', 'shortDate');

"

# ── Enable floating mode on bottom dock ────────────────────────────────────
DOCK_ID=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var b = panelIds.filter(function(id){ return panelById(id) && panelById(id).location === 'bottom'; }); print(b[b.length-1]);" \
    2>/dev/null | tail -1)

if [[ -n "${DOCK_ID:-}" && "$DOCK_ID" =~ ^[0-9]+$ ]]; then
    kwriteconfig6 \
        --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group "Containments" --group "$DOCK_ID" \
        --group "Configuration" --group "General" \
        --key "floating" "1"
    $DBUS_CMD org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "var p = panelById(${DOCK_ID}); if(p) p.reloadConfig();" 2>/dev/null || true
    echo "Floating mode applied to dock containment ${DOCK_ID}"
fi
