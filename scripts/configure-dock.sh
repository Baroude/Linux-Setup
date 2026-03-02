#!/usr/bin/env bash
# configure-dock.sh — Plasma 6 panel layout via JS scripting API
# Creates:
#   Bottom dock (no background, centered): Kickoff | icontasks [pinned apps]
#   Top bar     (transparent, full-width): AppMenu | Spacer | Media | SysMonitor | SysTray | Clock
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
// backgroundHints=0 → NoBackground: removes the pill/frame entirely (icons only)
var dock = new Panel;
dock.location   = 'bottom';
dock.height     = 56;
dock.alignment  = 'center';
dock.lengthMode = 'fit';
dock.currentConfigGroup = ['General'];
dock.writeConfig('backgroundHints', '0');

var kickoff = dock.addWidget('org.kde.plasma.kickoff');
kickoff.currentConfigGroup = ['General'];
kickoff.writeConfig('icon', '${VIBES_DIR}/apps-vibrant.svg');

var tasks = dock.addWidget('org.kde.plasma.icontasks');
tasks.currentConfigGroup = ['General'];
tasks.writeConfig('launchers', '${LAUNCHERS}');
tasks.writeConfig('showOnlyCurrentDesktop', 'false');

// ── Top bar ────────────────────────────────────────────────────────────────
// backgroundHints=0 → NoBackground: fully transparent bar
var top = new Panel;
top.location   = 'top';
top.height     = 36;
top.alignment  = 'center';
top.lengthMode = 'fill';
top.currentConfigGroup = ['General'];
top.writeConfig('backgroundHints', '0');

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

# ── Colorize top bar icons with Catppuccin Mocha palette ──────────────────
# Colors:Header controls icon/text color for panel widgets (symbolic icons,
# clock, appmenu text). ForegroundNormal = Catppuccin Text (soft white).
# DecorationFocus/Hover = Mauve accent so highlights pop with the theme.
# RGB format: "R,G,B"  (Catppuccin Mocha reference values)
KDEGLOBALS="$HOME/.config/kdeglobals"
kwriteconfig6 --file "$KDEGLOBALS" --group "Colors:Header" \
    --key "BackgroundNormal"    "30,30,46"        # base      #1e1e2e
kwriteconfig6 --file "$KDEGLOBALS" --group "Colors:Header" \
    --key "BackgroundAlternate" "24,24,37"        # mantle    #181825
kwriteconfig6 --file "$KDEGLOBALS" --group "Colors:Header" \
    --key "ForegroundNormal"    "205,214,244"     # text      #cdd6f4
kwriteconfig6 --file "$KDEGLOBALS" --group "Colors:Header" \
    --key "ForegroundInactive"  "166,173,200"     # subtext1  #a6adc8
kwriteconfig6 --file "$KDEGLOBALS" --group "Colors:Header" \
    --key "DecorationFocus"     "203,166,247"     # mauve     #cba6f7
kwriteconfig6 --file "$KDEGLOBALS" --group "Colors:Header" \
    --key "DecorationHover"     "203,166,247"     # mauve     #cba6f7

# Notify running KDE session to pick up the new colours
qdbus6 org.kde.KGlobalSettings /KGlobalSettings \
    org.kde.KGlobalSettings.notifyChange 0 0 2>/dev/null || true

echo "Top bar icon colours set to Catppuccin Mocha (mauve accents)"

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
