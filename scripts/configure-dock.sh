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

top.addWidget('org.kde.plasma.panelspacer');    // left flex → pushes clock to centre

var clock = top.addWidget('org.kde.plasma.digitalclock');
clock.currentConfigGroup = ['Configuration', 'Appearance'];
clock.writeConfig('showDate', 'true');
clock.writeConfig('dateDisplayFormat', '1');           // BesideTime: date first, time after
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
# Installs the preset file and writes globalSettings directly to the applet config.
if [[ -n "${TOP_ID:-}" && "$TOP_ID" =~ ^[0-9]+$ ]]; then
    # Install preset file so Panel Colorizer can also load it from the UI
    PC_PRESET_DIR="$HOME/.config/panel-colorizer/presets/Catppuccin Mocha Mauve"
    mkdir -p "$PC_PRESET_DIR"
    cp "${SCRIPT_DIR}/panel-colorizer-catppuccin.json" "$PC_PRESET_DIR/settings.json"
    echo "Panel Colorizer preset installed → $PC_PRESET_DIR/settings.json"

    # Discover live applet IDs and write config
    PANEL_ID="$TOP_ID" \
    PRESET_FILE="${SCRIPT_DIR}/panel-colorizer-catppuccin.json" \
    python3 << 'PYEOF'
import re, os, json, subprocess, sys

config_file = os.path.expanduser("~/.config/plasma-org.kde.plasma.desktop-appletsrc")
preset_file = os.environ['PRESET_FILE']
top_id      = os.environ['PANEL_ID']

# ── Find all applet plugin names under this containment ────────────────────
applet_plugins = {}   # "str_id" → "plugin.name"
current_section = None
with open(config_file) as f:
    for line in f:
        line = line.rstrip()
        if line.startswith('['):
            current_section = line
        elif current_section and line.startswith('plugin='):
            m = re.search(
                rf'\[Containments\]\[{re.escape(top_id)}\]\[Applets\]\[(\d+)\]$',
                current_section)
            if m:
                applet_plugins[m.group(1)] = line[7:]

print(f"Applets found in containment {top_id}:")
for aid, plug in sorted(applet_plugins.items(), key=lambda x: int(x[0])):
    print(f"  id={aid}  plugin={plug}")

pc_id = next((aid for aid, p in applet_plugins.items()
              if p == 'luisbocanegra.panel.colorizer'), None)
if not pc_id:
    print("ERROR: Panel Colorizer not found in top panel config — did the widget get added?",
          file=sys.stderr)
    sys.exit(1)

print(f"Panel Colorizer applet id: {pc_id}")

# ── Load preset and keep a single unified metrics widget ───────────────────
with open(preset_file) as f:
    preset = json.load(f)

gs = preset['globalSettings']
gs['unifiedBackground'] = []

gs_str = json.dumps(gs, separators=(',', ':'))

# ── Build configurationOverrides to disable panelspacer widgets ────────────
# Spacers advance the color-list counter but must not render a colored pill.
# configurationOverrides is a SEPARATE config key (not inside globalSettings)
# and is matched by both numeric id AND plugin name.
spacer_ids = sorted(
    [aid for aid, p in applet_plugins.items()
     if p == 'org.kde.plasma.panelspacer'],
    key=int)
print(f"Spacer applet ids: {spacer_ids}")
off = {
    "disabledFallback": True,
    "normal":          {"enabled": False},
    "busy":            {"enabled": False},
    "hovered":         {"enabled": False},
    "needsAttention":  {"enabled": False},
    "expanded":        {"enabled": False},
}
# panelspacer returns plasmoid.id=undefined → falls back to -1 at render time,
# so the association must use id=-1. Also include the real config IDs as
# belt-and-suspenders in case the behaviour differs across Plasma versions.
co = {
    "overrides": {"spacer_off": off},
    "associations": (
        [{"id": -1, "name": "org.kde.plasma.panelspacer", "presets": ["spacer_off"]}]
        + [{"id": int(sid), "name": "org.kde.plasma.panelspacer",
            "presets": ["spacer_off"]} for sid in spacer_ids]
    ),
}
co_str = json.dumps(co, separators=(',', ':'))

# ── Write settings via Plasma JS writeConfig (triggers configChanged live) ─
# kwriteconfig6 writes to the file but does NOT notify the running applet —
# Panel Colorizer caches globalSettings in memory and never sees those changes.
# widget.writeConfig() fires configChanged so Panel Colorizer applies immediately.
js_gs = gs_str.replace('\\', '\\\\').replace("'", "\\'")
js_co = co_str.replace('\\', '\\\\').replace("'", "\\'")
js_code = (
    # In Plasma 6 scripting API the property is w.type, not w.pluginName.
    # p.widgets(['plugin.id']) filters directly by type — cleanest approach.
    "var p = panelById(" + top_id + ");"
    "var pcs = p.widgets(['luisbocanegra.panel.colorizer']);"
    "if (pcs.length > 0) {"
    "  var pc = pcs[0];"
    "  pc.currentConfigGroup = ['General'];"
    "  pc.writeConfig('isEnabled', 'true');"
    "  pc.writeConfig('hideWidget', 'true');"
    "  pc.writeConfig('globalSettings', '" + js_gs + "');"
    "  pc.writeConfig('configurationOverrides', '" + js_co + "');"
    "  print('Panel Colorizer configured id=' + pc.id);"
    "} else {"
    "  print('WARNING: Panel Colorizer widget not found in top panel');"
    "}"
)
dbus_cmd = 'qdbus6'
if subprocess.run(['which', 'qdbus6'], capture_output=True).returncode != 0:
    dbus_cmd = 'qdbus'
result = subprocess.run(
    [dbus_cmd, 'org.kde.plasmashell', '/PlasmaShell',
     'org.kde.PlasmaShell.evaluateScript', js_code],
    capture_output=True, text=True
)
if result.stdout.strip():
    print(result.stdout.strip())
if result.returncode != 0:
    print("WARNING: JS writeConfig failed — falling back to kwriteconfig6", file=sys.stderr)
    base = ['kwriteconfig6', '--file', config_file,
            '--group', 'Containments', '--group', top_id,
            '--group', 'Applets',       '--group', pc_id,
            '--group', 'Configuration', '--group', 'General']
    subprocess.run(base + ['--key', 'isEnabled',      'true'],  check=True)
    subprocess.run(base + ['--key', 'hideWidget',     'true'],  check=True)
    subprocess.run(base + ['--key', 'globalSettings',  gs_str], check=True)

print(f"Panel Colorizer configured (applet id={pc_id})")
PYEOF

    echo "Panel Colorizer catppuccin islands applied to top bar"
fi
