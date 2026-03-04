#!/usr/bin/env bash
# configure-dock.sh — Plasma 6 panel layout via JS scripting API
# Creates:
#   Bottom dock (no background, centered): Kickoff | icontasks [pinned apps]
#   Top bar (transparent): Pager | Spacer | Clock | Spacer | Weather | AppMenu |
#             Media | CPU/RAM/Temp | SysTray | Lock/Logout | PanelColorizer(hidden)
#
# Panel Colorizer applies catppuccin Mocha pill islands — each widget gets its
# own distinct accent colour.
#
# Requires a running plasmashell session. Safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DBUS_CMD="qdbus6"
command -v qdbus6 &>/dev/null || DBUS_CMD="qdbus"

# ── Panel Colorizer install guard ──────────────────────────────────────────
if ! kpackagetool6 --list --type Plasma/Applet 2>/dev/null \
        | grep -q 'luisbocanegra.panel.colorizer'; then
    echo "ERROR: Panel Colorizer (luisbocanegra.panel.colorizer) is not installed." >&2
    echo "       Re-run setup.sh to install it (Phase 9b), or manually:" >&2
    echo "       kpackagetool6 --type Plasma/Applet --install <path>.plasmoid" >&2
    exit 1
fi
echo "Panel Colorizer detected — continuing"

# catppuccin-vibes SVG icons (downloaded by setup.sh Phase 6)
VIBES_DIR="$HOME/.local/share/icons/catppuccin-vibes"
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
# Double-quoted string so bash variables (LAUNCHERS, VIBES_DIR) expand into JS.
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
        titleWidget.writeConfig('windowTitleHideEmpty', 'false');
        titleWidget.writeConfig('windowTitleUndefined', 'Desktop');
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

# ── Enable floating mode on bottom dock ────────────────────────────────────
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

# ── Panel Colorizer: catppuccin Mocha pill islands ─────────────────────────
# Applet IDs are discovered via the live JS API (not the appletsrc file) to
# avoid a race condition where Plasma hasn't yet flushed the newly-created
# panel to disk. kwriteconfig6 always writes to disk for reboot persistence;
# JS writeConfig also fires configChanged for immediate live application.
if [[ -n "${TOP_ID:-}" && "$TOP_ID" =~ ^[0-9]+$ ]]; then
    # Install preset file so Panel Colorizer can also load it from the UI
    PC_PRESET_DIR="$HOME/.config/panel-colorizer/presets/Catppuccin Mocha Mauve"
    mkdir -p "$PC_PRESET_DIR"
    cp "${SCRIPT_DIR}/panel-colorizer-catppuccin.json" "$PC_PRESET_DIR/settings.json"
    echo "Panel Colorizer preset installed → $PC_PRESET_DIR/settings.json"

    # ── Discover applet IDs via live JS API (no file-read race condition) ──
    PC_ID=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "var p=panelById(${TOP_ID}); var ws=p.widgets(['luisbocanegra.panel.colorizer']); print(ws.length>0?ws[0].id:'NOT_FOUND');" \
        2>/dev/null | tail -1)
    [[ "${PC_ID:-}" =~ ^[0-9]+$ ]] || {
        echo "ERROR: Panel Colorizer not found in top panel" >&2; exit 1; }
    echo "Panel Colorizer applet id: ${PC_ID}"

    SPACER_IDS_JSON=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "var p=panelById(${TOP_ID}); var ws=p.widgets(['org.kde.plasma.panelspacer']); var ids=[]; ws.forEach(function(w){ids.push(w.id);}); print(JSON.stringify(ids));" \
        2>/dev/null | tail -1)
    echo "Spacer applet ids: ${SPACER_IDS_JSON}"

    TOP_WIDGETS_JSON=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "var p=panelById(${TOP_ID}); var ws=p.widgets(); var out=[]; ws.forEach(function(w){out.push({id:w.id,name:w.type});}); print(JSON.stringify(out));" \
        2>/dev/null | tail -1)
    echo "Top panel widgets: ${TOP_WIDGETS_JSON}"
    if [[ -n "${TITLE_WIDGET_ID:-}" ]] && ! echo "${TOP_WIDGETS_JSON}" | grep -Fq "\"name\":\"${TITLE_WIDGET_ID}\""; then
        echo "WARNING: Title widget (${TITLE_WIDGET_ID}) was not added to the top panel." >&2
        echo "         Try: systemctl --user restart plasma-plasmashell.service" >&2
        echo "         Then re-run: bash scripts/configure-dock.sh" >&2
    fi

    # ── Build JSON configs and write via kwriteconfig6 + JS writeConfig ────
    PANEL_ID="$TOP_ID" \
    APPLET_ID="$PC_ID" \
    PRESET_FILE="${SCRIPT_DIR}/panel-colorizer-catppuccin.json" \
    SPACER_IDS_JSON="${SPACER_IDS_JSON:-[]}" \
    TOP_WIDGETS_JSON="${TOP_WIDGETS_JSON:-[]}" \
    python3 << 'PYEOF'
import copy, os, json, re, subprocess, sys

config_file = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
preset_file = os.environ['PRESET_FILE']
top_id      = os.environ['PANEL_ID']
pc_id       = os.environ['APPLET_ID']
spacer_ids  = json.loads(os.environ.get('SPACER_IDS_JSON', '[]'))
top_widgets = json.loads(os.environ.get('TOP_WIDGETS_JSON', '[]'))

print(f"Panel Colorizer applet id: {pc_id}")
print(f"Spacer applet ids: {spacer_ids}")
print(f"Top panel widgets: {top_widgets}")

# ── Load preset ────────────────────────────────────────────────────────────
with open(preset_file) as f:
    preset = json.load(f)

gs = preset['globalSettings']
gs['unifiedBackground'] = []
# Disable positional list-based coloring; use explicit per-widget overrides.
widget_bg = gs.setdefault('widgets', {}).setdefault('normal', {}).setdefault('backgroundColor', {})
widget_bg['sourceType'] = 0
widget_bg['list'] = []
widget_bg['custom'] = '#313244'
widget_bg['enabled'] = True
gs_str = json.dumps(gs, separators=(',', ':'))

off = {
    "disabledFallback": True,
    "normal": {"enabled": False},
    "busy": {"enabled": False},
    "hovered": {"enabled": False},
    "needsAttention": {"enabled": False},
    "expanded": {"enabled": False},
}

def make_color_override(bg_hex, fg_hex="#1e1e2e"):
    normal = copy.deepcopy(gs.get("widgets", {}).get("normal", {}))
    normal["enabled"] = True
    bg_cfg = normal.setdefault("backgroundColor", {})
    bg_cfg.update({
        "enabled": True,
        "sourceType": 0,
        "custom": bg_hex,
        "alpha": 1,
        "list": [],
    })
    fg_cfg = normal.setdefault("foregroundColor", {})
    fg_cfg.update({
        "enabled": True,
        "sourceType": 0,
        "custom": fg_hex,
        "alpha": 1,
        "list": [],
    })
    return {
        "disabledFallback": True,
        "normal": normal,
        "busy": {"enabled": False},
        "hovered": {"enabled": False},
        "needsAttention": {"enabled": False},
        "expanded": {"enabled": False},
    }

widget_colors = {
    "org.kde.plasma.pager": "#b4befe",
    "org.kde.plasma.windowtitle": "#a6adc8",
    "com.github.antroids.application-title-bar": "#a6adc8",
    "org.kde.plasma.digitalclock": "#cba6f7",
    "org.kde.plasma.weather": "#89b4fa",
    "org.kde.plasma.appmenu": "#a6e3a1",
    "org.kde.plasma.mediacontroller": "#94e2d5",
    "org.kde.plasma.systemmonitor": "#fab387",
    "org.kde.plasma.systemtray": "#89dceb",
    "org.kde.plasma.lock_logout": "#f38ba8",
}

def override_name(widget_name):
    return "color_" + re.sub(r"[^a-zA-Z0-9_]+", "_", widget_name).strip("_")

overrides = {
    "spacer_off": off,
    "colorizer_off": off,
}
associations = []
seen_associations = set()

def add_association(widget_id, widget_name, preset_name):
    key = (int(widget_id), widget_name, preset_name)
    if key in seen_associations:
        return
    seen_associations.add(key)
    associations.append({
        "id": int(widget_id),
        "name": widget_name,
        "presets": [preset_name],
    })

# Spacers sometimes report plasmoid.id as -1; keep both specific IDs and generic.
add_association(-1, "org.kde.plasma.panelspacer", "spacer_off")
for sid in spacer_ids:
    add_association(int(sid), "org.kde.plasma.panelspacer", "spacer_off")

for widget in top_widgets:
    name = widget.get("name")
    wid = widget.get("id", -1)
    if not name:
        continue
    if name == "org.kde.plasma.panelspacer":
        add_association(int(wid), name, "spacer_off")
        continue
    if name == "luisbocanegra.panel.colorizer":
        add_association(int(wid), name, "colorizer_off")
        continue
    if name not in widget_colors:
        continue
    ov_name = override_name(name)
    if ov_name not in overrides:
        overrides[ov_name] = make_color_override(widget_colors[name])
    add_association(int(wid), name, ov_name)

co = {
    "overrides": overrides,
    "associations": associations,
}
co_str = json.dumps(co, separators=(',', ':'))

# ── 1. kwriteconfig6: write to disk (persists across reboots) ─────────────
base = ['kwriteconfig6', '--file', config_file,
        '--group', 'Containments', '--group', top_id,
        '--group', 'Applets',       '--group', pc_id,
        '--group', 'Configuration', '--group', 'General']
subprocess.run(base + ['--key', 'isEnabled',              'true'],   check=True)
subprocess.run(base + ['--key', 'hideWidget',             'true'],   check=True)
subprocess.run(base + ['--key', 'globalSettings',          gs_str],  check=True)
subprocess.run(base + ['--key', 'configurationOverrides',  co_str],  check=True)
print(f"Panel Colorizer config written to disk (applet id={pc_id})")

# ── 2. JS writeConfig: apply in live session (fires configChanged) ─────────
dbus_cmd = 'qdbus6'
if subprocess.run(['which', 'qdbus6'], capture_output=True).returncode != 0:
    dbus_cmd = 'qdbus'
js_gs = gs_str.replace('\\', '\\\\').replace("'", "\\'")
js_co = co_str.replace('\\', '\\\\').replace("'", "\\'")
js_code = (
    f"var p=panelById({top_id});"
    "var ws=p.widgets(['luisbocanegra.panel.colorizer']);"
    "if(ws.length>0){"
    "  var w=ws[0]; w.currentConfigGroup=['General'];"
    "  w.writeConfig('isEnabled','true');"
    "  w.writeConfig('hideWidget','true');"
    f"  w.writeConfig('globalSettings','{js_gs}');"
    f"  w.writeConfig('configurationOverrides','{js_co}');"
    "  print('Panel Colorizer live-configured id='+w.id);"
    "}else{ print('WARNING: Panel Colorizer not found for live config'); }"
)
result = subprocess.run(
    [dbus_cmd, 'org.kde.plasmashell', '/PlasmaShell',
     'org.kde.PlasmaShell.evaluateScript', js_code],
    capture_output=True, text=True
)
if result.stdout.strip():
    print(result.stdout.strip())
if result.returncode != 0:
    print(f"WARNING: JS live config failed (disk config was written): {result.stderr.strip()}",
          file=sys.stderr)

print(f"Panel Colorizer configured (applet id={pc_id})")
PYEOF

    echo "Panel Colorizer catppuccin islands applied to top bar"
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
