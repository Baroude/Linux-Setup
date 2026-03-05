#!/usr/bin/env bash
# configure-dock.sh — Plasma 6 panel layout via JS scripting API
# Creates:
#   Bottom dock (no background, centered): icontasks [pinned apps]
#   Top bar (transparent): Pager | Spacer | Clock | Spacer | Weather | AppMenu |
#             Media | CPU/RAM/Temp | SysTray | Lock/Logout | PanelColorizer(hidden)
#
# Panel Colorizer styling is resolved from the active theme state.
#
# Requires a running plasmashell session. Safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DBUS_CMD="qdbus6"
command -v qdbus6 &>/dev/null || DBUS_CMD="qdbus"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/theme-common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/theme-apply-panel.sh"

# ── Panel Colorizer install guard ──────────────────────────────────────────
if ! kpackagetool6 --list --type Plasma/Applet 2>/dev/null \
        | grep -q 'luisbocanegra.panel.colorizer'; then
    echo "ERROR: Panel Colorizer (luisbocanegra.panel.colorizer) is not installed." >&2
    echo "       Re-run setup.sh to install it (Phase 9b), or manually:" >&2
    echo "       kpackagetool6 --type Plasma/Applet --install <path>.plasmoid" >&2
    exit 1
fi
echo "Panel Colorizer detected — continuing"

APP_TITLEBAR_ID="com.github.antroids.application-title-bar"
APP_TITLEBAR_URL="${APP_TITLEBAR_URL:-https://github.com/antroids/application-title-bar/releases/latest/download/application-title-bar.plasmoid}"

has_plasmoid() {
    local plugin_id="$1"
    kpackagetool6 --list --type Plasma/Applet 2>/dev/null | grep -Fq "$plugin_id" && return 0
    [[ -d "$HOME/.local/share/plasma/plasmoids/$plugin_id" ]] && return 0
    [[ -d "/usr/share/plasma/plasmoids/$plugin_id" ]] && return 0
    return 1
}

install_application_titlebar() {
    local tmp_pkg downloader_ok=0
    tmp_pkg="$(mktemp /tmp/application-title-bar.XXXXXX.plasmoid 2>/dev/null || mktemp)"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$tmp_pkg" "$APP_TITLEBAR_URL" && downloader_ok=1
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$tmp_pkg" "$APP_TITLEBAR_URL" && downloader_ok=1
    fi
    if [[ "$downloader_ok" -eq 1 ]]; then
        kpackagetool6 -t Plasma/Applet -u "$tmp_pkg" >/dev/null 2>&1 \
            || kpackagetool6 -t Plasma/Applet -i "$tmp_pkg" >/dev/null 2>&1 \
            || true
    fi
    rm -f "$tmp_pkg"
}

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
sleep 0.5   # wait for KWin to apply desktop count before pager widget is created
echo "Virtual desktops set to 4"

# Window title/buttons widget selection:
# 1) Plasma 6 replacement with title + min/max/close buttons
# 2) Legacy Plasma 5 window title widget (title only)
TITLE_WIDGET_ID=""
if has_plasmoid "$APP_TITLEBAR_ID"; then
    TITLE_WIDGET_ID="$APP_TITLEBAR_ID"
    echo "Window title/buttons widget detected: ${TITLE_WIDGET_ID}"
elif kpackagetool6 --list --type Plasma/Applet 2>/dev/null \
        | grep -q 'org.kde.plasma.windowtitle'; then
    TITLE_WIDGET_ID="org.kde.plasma.windowtitle"
    echo "Window title widget detected: ${TITLE_WIDGET_ID}"
else
    echo "Window title widget not found, attempting install of ${APP_TITLEBAR_ID}..."
    install_application_titlebar
    if has_plasmoid "$APP_TITLEBAR_ID"; then
        TITLE_WIDGET_ID="$APP_TITLEBAR_ID"
        echo "Installed and detected: ${TITLE_WIDGET_ID}"
    else
        echo "WARNING: No window title widget found." >&2
        echo "         Top bar will not show window title/buttons." >&2
        echo "         Install manually: ${APP_TITLEBAR_URL}" >&2
    fi
fi

# ── Apply panel layout via Plasma JS ───────────────────────────────────────
# Double-quoted string so bash variables (LAUNCHERS, TITLE_WIDGET_ID) expand into JS.
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

var tasks = dock.addWidget('org.kde.plasma.icontasks');
tasks.currentConfigGroup = ['General'];
tasks.writeConfig('launchers', '${LAUNCHERS}');
tasks.writeConfig('showOnlyCurrentDesktop', 'false');

// ── Top bar ────────────────────────────────────────────────────────────────
// backgroundHints=0 → NoBackground: fully transparent bar (belt-and-braces;
// kwriteconfig6 below also sets panelOpacity=2 for the compositor layer).
var top = new Panel;
top.location   = 'top';
top.height     = 36;
top.alignment  = 'center';
top.lengthMode = 'fill';
top.currentConfigGroup = ['General'];
top.writeConfig('backgroundHints', '0');

var pager = top.addWidget('org.kde.plasma.pager');  // far left
pager.currentConfigGroup = ['General'];
pager.writeConfig('displayedText', '0');            // Number
pager.writeConfig('showWindowOutlines', 'false');
pager.writeConfig('showWindowIcons', 'false');
pager.writeConfig('pagerLayout', '1');              // Horizontal
pager.writeConfig('showOnlyCurrentScreen', 'true');

// Optional title/buttons widget:
// - com.github.antroids.application-title-bar (Plasma 6, title + buttons)
// - org.kde.plasma.windowtitle (legacy, title only)
var titleWidget = null;
if ('${TITLE_WIDGET_ID}') {
    try {
        titleWidget = top.addWidget('${TITLE_WIDGET_ID}');
    } catch(e) {
        print('WARNING: title widget not available: ' + e);
    }
}
if (titleWidget && typeof titleWidget.writeConfig === 'function') {
    if ('${TITLE_WIDGET_ID}' === 'org.kde.plasma.windowtitle') {
        // source=0: applicationName avoids empty title when hide_window_decorations=yes
        titleWidget.currentConfigGroup = ['General'];
        titleWidget.writeConfig('fillWidth', 'false');
        titleWidget.writeConfig('source', '0');
    } else if ('${TITLE_WIDGET_ID}' === 'com.github.antroids.application-title-bar') {
        // Keep defaults, force appName title source and broad task matching.
        titleWidget.currentConfigGroup = ['Appearance'];
        titleWidget.writeConfig('widgetElements', 'windowMinimizeButton,windowCloseButton,windowTitle');
        titleWidget.writeConfig('windowTitleSource', '0');
        titleWidget.writeConfig('windowTitleHideEmpty', 'true');
        titleWidget.writeConfig('windowTitleUndefined', '');
        titleWidget.writeConfig('windowTitleMinimumWidth', '120');
        titleWidget.writeConfig('windowTitleMaximumWidth', '420');
        titleWidget.writeConfig('widgetFillWidth', 'false');
        titleWidget.currentConfigGroup = ['Behavior'];
        titleWidget.writeConfig('widgetActiveTaskSource', '1');
        titleWidget.writeConfig('widgetActiveTaskFilterByActivity', 'false');
        titleWidget.writeConfig('widgetActiveTaskFilterByScreen', 'false');
        titleWidget.writeConfig('widgetActiveTaskFilterByVirtualDesktop', 'false');
        titleWidget.writeConfig('widgetActiveTaskFilterNotMaximized', 'false');
        titleWidget.writeConfig('disableButtonsForNotHoveredWidget', 'false');
    }
}

top.addWidget('org.kde.plasma.panelspacer');    // left flex → pushes clock to centre

var clock = top.addWidget('org.kde.plasma.digitalclock');
clock.currentConfigGroup = ['Configuration', 'Appearance'];
clock.writeConfig('showDate', 'true');
clock.writeConfig('dateFormat', 'longDate');
clock.writeConfig('dateDisplayFormat', '1');  // 1 = date beside time, 0/unset = below
clock.writeConfig('customFont', 'true');
clock.writeConfig('fontFamily', 'Inter');
clock.writeConfig('fontSize', '10');
clock.writeConfig('boldText', 'false');

top.addWidget('org.kde.plasma.panelspacer');    // right flex → pushes right group away

// right group: weather, appmenu, media, inline metrics, systray, power
top.addWidget('org.kde.plasma.weather');
top.addWidget('org.kde.plasma.appmenu');
top.addWidget('org.kde.plasma.mediacontroller');

// Unified metrics island: CPU %, RAM %, CPU temperature (icon-only labels)
var metrics = top.addWidget('org.kde.plasma.systemmonitor');
metrics.currentConfigGroup = ['Sensors'];
metrics.writeConfig('highPrioritySensorIds', '[\"cpu/all/usage\",\"memory/physical/usedPercent\",\"cpu/all/averageTemperature\"]');
metrics.writeConfig('totalSensors',          '[\"cpu/all/usage\",\"memory/physical/usedPercent\",\"cpu/all/averageTemperature\"]');
metrics.currentConfigGroup = ['SensorLabels'];
metrics.writeConfig('cpu/all/usage', '');
metrics.writeConfig('memory/physical/usedPercent', '󰍛');
metrics.writeConfig('cpu/all/averageTemperature', '');
metrics.currentConfigGroup = ['Appearance'];
metrics.writeConfig('chartFace', 'org.kde.ksysguard.textonly');
metrics.writeConfig('title', '');

top.addWidget('org.kde.plasma.systemtray');
var session = top.addWidget('org.kde.plasma.lock_logout');   // far-right session controls
session.currentConfigGroup = ['General'];
session.writeConfig('show_lockScreen', 'true');
session.writeConfig('show_requestShutDown', 'true');
session.writeConfig('show_requestReboot', 'true');
session.writeConfig('show_requestLogout', 'true');
session.writeConfig('show_requestLogoutScreen', 'false');

// Panel Colorizer — hidden control widget; applies catppuccin pill islands.
// globalSettings are written by the Python block below after panel IDs are known.
var colorizer = top.addWidget('luisbocanegra.panel.colorizer');
colorizer.currentConfigGroup = ['General'];
colorizer.writeConfig('hideWidget', 'true');

// Remove native Plasma applet frame SVG from every top-bar widget so Panel
// Colorizer pills render without a dark border underneath them.
top.widgets().forEach(function(w) {
    w.currentConfigGroup = ['Configuration', 'General'];
    w.writeConfig('backgroundHints', '0');
});

"

# ── Detect panel IDs ───────────────────────────────────────────────────────
TOP_ID=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var t = panelIds.filter(function(id){ return panelById(id) && panelById(id).location === 'top'; }); print(t[t.length-1]);" \
    2>/dev/null | tail -1)

DOCK_ID=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var b = panelIds.filter(function(id){ return panelById(id) && panelById(id).location === 'bottom'; }); print(b[b.length-1]);" \
    2>/dev/null | tail -1)

# ── Remove top bar background via kwriteconfig6 + reloadConfig ────────────
# JS writeConfig alone doesn't survive without an explicit reloadConfig call.
# backgroundHints=0 → NoBackground (removes SVG decoration)
# panelOpacity=2    → Translucent (the key Plasma's own right-click menu writes)
if [[ -n "${TOP_ID:-}" && "$TOP_ID" =~ ^[0-9]+$ ]]; then
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

# ── Enable floating mode and transparency on bottom dock ───────────────────
if [[ -n "${DOCK_ID:-}" && "$DOCK_ID" =~ ^[0-9]+$ ]]; then
    kwriteconfig6 \
        --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group "Containments" --group "$DOCK_ID" \
        --group "Configuration" --group "General" \
        --key "floating" "1"
    kwriteconfig6 \
        --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group "Containments" --group "$DOCK_ID" \
        --group "Configuration" --group "General" \
        --key "backgroundHints" "0"
    kwriteconfig6 \
        --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" \
        --group "Containments" --group "$DOCK_ID" \
        --group "Configuration" --group "General" \
        --key "panelOpacity" "2"
    $DBUS_CMD org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "var p = panelById(${DOCK_ID}); if(p) p.reloadConfig();" 2>/dev/null || true
    echo "Floating transparent dock applied to containment ${DOCK_ID}"
fi

# -- Panel Colorizer: apply active theme styling ----------------------------
if [[ -n "${TOP_ID:-}" && "$TOP_ID" =~ ^[0-9]+$ ]]; then
    DEFAULTS_JSON="$(theme_defaults_json)"
    DEFAULT_THEME="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["theme"])' <<<"$DEFAULTS_JSON")"
    DEFAULT_FLAVOR="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["flavor"])' <<<"$DEFAULTS_JSON")"
    DEFAULT_ACCENT="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["accent"])' <<<"$DEFAULTS_JSON")"

    STATE_THEME=""
    STATE_FLAVOR=""
    STATE_ACCENT=""
    if readarray -t STATE_TRIPLET < <(theme_read_state_selection 2>/dev/null); then
        STATE_THEME="${STATE_TRIPLET[0]:-}"
        STATE_FLAVOR="${STATE_TRIPLET[1]:-}"
        STATE_ACCENT="${STATE_TRIPLET[2]:-}"
    fi

    SELECTED_THEME="${STATE_THEME:-$DEFAULT_THEME}"
    SELECTED_FLAVOR="${STATE_FLAVOR:-$DEFAULT_FLAVOR}"
    SELECTED_ACCENT="${STATE_ACCENT:-$DEFAULT_ACCENT}"
    if ! theme_validate_selection "$SELECTED_THEME" "$SELECTED_FLAVOR" "$SELECTED_ACCENT"; then
        SELECTED_THEME="$DEFAULT_THEME"
        SELECTED_FLAVOR="$DEFAULT_FLAVOR"
        SELECTED_ACCENT="$DEFAULT_ACCENT"
    fi

    THEME_CONTEXT_JSON="$(theme_build_context_json "$SELECTED_THEME" "$SELECTED_FLAVOR" "$SELECTED_ACCENT")"
    export THEME_CONTEXT_JSON
    theme_panel_prepare_assets

    PANEL_PRESET_NAME="Catppuccin ${SELECTED_FLAVOR^} ${SELECTED_ACCENT^}"
    PC_PRESET_DIR="$HOME/.config/panel-colorizer/presets/${PANEL_PRESET_NAME}"
    mkdir -p "$PC_PRESET_DIR"
    cp "$THEME_PANEL_PRESET_FILE" "$PC_PRESET_DIR/settings.json"
    echo "Panel Colorizer preset installed -> $PC_PRESET_DIR/settings.json"

    if theme_panel_apply_live 1; then
        echo "Panel Colorizer themed islands applied to top bar"
    else
        echo "WARNING: Panel Colorizer applet not ready; run scripts/apply-panel-colorizer.sh after login" >&2
    fi
fi

# ── Register autostart to re-apply Panel Colorizer on every login ──────────
# Panel Colorizer saves its own (Macchiato) state to appletsrc on logout,
# overwriting our Mocha config. The autostart script re-applies Mocha after
# Panel Colorizer initialises on the next login.
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/apply-panel-colorizer.desktop" << DESKTOP_EOF
[Desktop Entry]
Name=Panel Colorizer Catppuccin Mocha
Exec=bash "${SCRIPT_DIR}/apply-panel-colorizer.sh"
Type=Application
X-KDE-autostart-phase=2
DESKTOP_EOF
echo "Autostart registered: ${AUTOSTART_DIR}/apply-panel-colorizer.desktop"
