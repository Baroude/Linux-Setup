#!/usr/bin/env bash
# configure-dock.sh — Plasma 6 panel layout via JS scripting API
# Creates:
#   Bottom dock (no background, centered): Kickoff | icontasks [pinned apps]
#   Top bar (transparent): Pager | Spacer | Clock | Spacer | Weather | AppMenu | Media | CPU% | RAM% | SysTray
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

# ── Virtual desktops — pager hides itself when only 1 desktop exists ───────
kwriteconfig6 --file "$HOME/.config/kwinrc" --group "Desktops" --key "Number" "4"
kwriteconfig6 --file "$HOME/.config/kwinrc" --group "Desktops" --key "Rows"   "1"
qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
echo "Virtual desktops set to 4"

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

top.addWidget('org.kde.plasma.pager');          // far left

top.addWidget('org.kde.plasma.panelspacer');    // left flex → pushes clock to centre

var clock = top.addWidget('org.kde.plasma.digitalclock');
clock.currentConfigGroup = ['Configuration', 'Appearance'];
clock.writeConfig('showDate', 'true');
clock.writeConfig('dateDisplayFormat', 'BelowTime');
clock.writeConfig('dateFormat', 'shortDate');

top.addWidget('org.kde.plasma.panelspacer');    // right flex → pushes right group away

// right group: weather, appmenu, media, then inline CPU% and RAM%, then systray
top.addWidget('org.kde.plasma.weather');
top.addWidget('org.kde.plasma.appmenu');
top.addWidget('org.kde.plasma.mediacontroller');

// CPU usage — text-only face shows the percentage directly in the bar
var cpu = top.addWidget('org.kde.plasma.systemmonitor');
cpu.currentConfigGroup = ['Sensors'];
cpu.writeConfig('highPrioritySensorIds', '["cpu/all/usage"]');
cpu.writeConfig('totalSensors',          '["cpu/all/usage"]');
cpu.currentConfigGroup = ['Appearance'];
cpu.writeConfig('chartFace', 'org.kde.ksysguard.textonly');

// RAM usage — same approach, physical memory used %
var mem = top.addWidget('org.kde.plasma.systemmonitor');
mem.currentConfigGroup = ['Sensors'];
mem.writeConfig('highPrioritySensorIds', '["memory/physical/usedPercent"]');
mem.writeConfig('totalSensors',          '["memory/physical/usedPercent"]');
mem.currentConfigGroup = ['Appearance'];
mem.writeConfig('chartFace', 'org.kde.ksysguard.textonly');

top.addWidget('org.kde.plasma.systemtray');

"

# ── Colorize top bar icons with Catppuccin Mocha palette ──────────────────
# Writing to kdeglobals alone doesn't stick — the active color scheme
# overrides it whenever KDE refreshes. Instead, patch the installed scheme
# file directly so the values survive reapplication, then reapply the scheme.
# RGB format: "R,G,B"  (Catppuccin Mocha reference values)
SCHEME_FILE="$HOME/.local/share/color-schemes/CatppuccinMochaMauve.colors"
if [[ -f "$SCHEME_FILE" ]]; then
    kwriteconfig6 --file "$SCHEME_FILE" --group "Colors:Header" \
        --key "BackgroundNormal"    "30,30,46"    # base      #1e1e2e
    kwriteconfig6 --file "$SCHEME_FILE" --group "Colors:Header" \
        --key "BackgroundAlternate" "24,24,37"    # mantle    #181825
    kwriteconfig6 --file "$SCHEME_FILE" --group "Colors:Header" \
        --key "ForegroundNormal"    "203,166,247" # mauve     #cba6f7
    kwriteconfig6 --file "$SCHEME_FILE" --group "Colors:Header" \
        --key "ForegroundInactive"  "166,173,200" # subtext1  #a6adc8
    kwriteconfig6 --file "$SCHEME_FILE" --group "Colors:Header" \
        --key "DecorationFocus"     "203,166,247" # mauve     #cba6f7
    kwriteconfig6 --file "$SCHEME_FILE" --group "Colors:Header" \
        --key "DecorationHover"     "203,166,247" # mauve     #cba6f7
    # Reapply so the running session picks up the patched scheme
    plasma-apply-colorscheme CatppuccinMochaMauve 2>/dev/null || \
        qdbus6 org.kde.KGlobalSettings /KGlobalSettings \
            org.kde.KGlobalSettings.notifyChange 0 0 2>/dev/null || true
    echo "Catppuccin Mocha scheme patched and reapplied (mauve panel icons)"
else
    echo "WARNING: CatppuccinMochaMauve.colors not found — run Phase 3 of setup.sh first"
fi

# ── Remove top bar background via kwriteconfig6 + reloadConfig ────────────
# JS writeConfig alone doesn't survive without an explicit reloadConfig call.
# Mirror the same pattern used for the dock's floating flag.
TOP_ID=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var t = panelIds.filter(function(id){ return panelById(id) && panelById(id).location === 'top'; }); print(t[t.length-1]);" \
    2>/dev/null | tail -1)

if [[ -n "${TOP_ID:-}" && "$TOP_ID" =~ ^[0-9]+$ ]]; then
    # backgroundHints=0 → NoBackground (removes SVG decoration)
    # panelOpacity=2    → Translucent (the key Plasma's own right-click menu writes)
    # Both are needed: backgroundHints handles the containment SVG layer,
    # panelOpacity handles the PanelView compositor layer.
    kwriteconfig6 \
        --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group "Containments" --group "$TOP_ID" \
        --group "Configuration" --group "General" \
        --key "backgroundHints" "0"
    kwriteconfig6 \
        --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group "Containments" --group "$TOP_ID" \
        --group "Configuration" --group "General" \
        --key "panelOpacity" "2"
    $DBUS_CMD org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "var p = panelById(${TOP_ID}); if(p) p.reloadConfig();" 2>/dev/null || true
    echo "Transparent top bar applied to containment ${TOP_ID}"
fi

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
