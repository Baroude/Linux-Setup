#!/usr/bin/env bash
# configure-dock.sh — Plasma 6 panel layout via JS scripting API
# Creates:
#   Bottom dock (no background, centered): Kickoff | icontasks [pinned apps]
#   Top bar (transparent): Pager | Spacer | Clock | Spacer | Weather | AppMenu |
#             Media | CPU | RAM | SysTray | PanelColorizer(hidden)
#
# Panel Colorizer applies catppuccin Mocha pill islands — each widget gets its
# own distinct accent colour. CPU and RAM share a unified Peach island.
#
# Requires a running plasmashell session. Safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

top.addWidget('org.kde.plasma.pager');          // far left

top.addWidget('org.kde.plasma.panelspacer');    // left flex → pushes clock to centre

var clock = top.addWidget('org.kde.plasma.digitalclock');
clock.currentConfigGroup = ['Configuration', 'Appearance'];
clock.writeConfig('showDate', 'true');
clock.writeConfig('dateDisplayFormat', 'BelowTime');
clock.writeConfig('dateFormat', 'shortDate');

top.addWidget('org.kde.plasma.panelspacer');    // right flex → pushes right group away

// right group: weather, appmenu, media, inline CPU% and RAM%, systray
top.addWidget('org.kde.plasma.weather');
top.addWidget('org.kde.plasma.appmenu');
top.addWidget('org.kde.plasma.mediacontroller');

// CPU usage — text-only face shows the percentage directly in the bar
var cpu = top.addWidget('org.kde.plasma.systemmonitor');
cpu.currentConfigGroup = ['Sensors'];
cpu.writeConfig('highPrioritySensorIds', '[\"cpu/all/usage\"]');
cpu.writeConfig('totalSensors',          '[\"cpu/all/usage\"]');
cpu.currentConfigGroup = ['Appearance'];
cpu.writeConfig('chartFace', 'org.kde.ksysguard.textonly');

// RAM usage — same approach, physical memory used %
var mem = top.addWidget('org.kde.plasma.systemmonitor');
mem.currentConfigGroup = ['Sensors'];
mem.writeConfig('highPrioritySensorIds', '[\"memory/physical/usedPercent\"]');
mem.writeConfig('totalSensors',          '[\"memory/physical/usedPercent\"]');
mem.currentConfigGroup = ['Appearance'];
mem.writeConfig('chartFace', 'org.kde.ksysguard.textonly');

top.addWidget('org.kde.plasma.systemtray');

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
# Installs the preset file and writes globalSettings (with the live CPU+RAM
# applet IDs patched in for the unified island) directly to the applet config.
if [[ -n "${TOP_ID:-}" && "$TOP_ID" =~ ^[0-9]+$ ]]; then
    # Install preset file so Panel Colorizer can also load it from the UI
    PC_PRESET_DIR="$HOME/.config/panel-colorizer/presets/Catppuccin Mocha Mauve"
    mkdir -p "$PC_PRESET_DIR"
    cp "${SCRIPT_DIR}/panel-colorizer-catppuccin.json" "$PC_PRESET_DIR/settings.json"
    echo "Panel Colorizer preset installed → $PC_PRESET_DIR/settings.json"

    # Discover live applet IDs, patch unifiedBackground, write config
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

pc_id = next((aid for aid, p in applet_plugins.items()
              if p == 'luisbocanegra.panel.colorizer'), None)
if not pc_id:
    print("WARNING: Panel Colorizer not found in top panel config", file=sys.stderr)
    sys.exit(0)

# Systemmonitor applets in creation order (lower numeric ID = created first = CPU)
sysmon_ids = sorted(
    [aid for aid, p in applet_plugins.items() if p == 'org.kde.plasma.systemmonitor'],
    key=int)

# ── Load preset and patch unifiedBackground with live applet IDs ───────────
with open(preset_file) as f:
    preset = json.load(f)

gs = preset['globalSettings']
if len(sysmon_ids) >= 2:
    cpu_id = int(sysmon_ids[-2])
    ram_id = int(sysmon_ids[-1])
    # unifyBgType 1 = island start, 3 = island end
    gs['unifiedBackground'] = [
        {'id': cpu_id, 'unifyBgType': 1},
        {'id': ram_id, 'unifyBgType': 3},
    ]
    print(f"Unified CPU (id={cpu_id}) + RAM (id={ram_id}) as one Peach island")
else:
    print("WARNING: < 2 systemmonitor applets found; skipping unified island",
          file=sys.stderr)

gs_str = json.dumps(gs, separators=(',', ':'))

# ── Write settings to Panel Colorizer applet config group ─────────────────
base = ['kwriteconfig6', '--file', config_file,
        '--group', 'Containments', '--group', top_id,
        '--group', 'Applets',       '--group', pc_id,
        '--group', 'Configuration', '--group', 'General']
subprocess.run(base + ['--key', 'isEnabled',      'true'],  check=True)
subprocess.run(base + ['--key', 'hideWidget',     'true'],  check=True)
subprocess.run(base + ['--key', 'globalSettings',  gs_str], check=True)

print(f"Panel Colorizer configured (applet id={pc_id})")
PYEOF

    # Reload the containment so Panel Colorizer picks up its new globalSettings
    $DBUS_CMD org.kde.plasmashell /PlasmaShell \
        org.kde.PlasmaShell.evaluateScript \
        "var p = panelById(${TOP_ID}); if(p) p.reloadConfig();" 2>/dev/null || true
    echo "Panel Colorizer catppuccin islands applied to top bar"
fi
