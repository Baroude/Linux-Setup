#!/usr/bin/env bash
# apply-panel-colorizer.sh
# KDE autostart — re-applies Catppuccin Mocha Mauve Panel Colorizer config
# after Panel Colorizer has loaded (and overwritten our config with its own state).
# Registered as autostart by configure-dock.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESET_FILE="${SCRIPT_DIR}/panel-colorizer-catppuccin.json"
DBUS_CMD="qdbus6"
command -v qdbus6 &>/dev/null || DBUS_CMD="qdbus"

# ── Wait for plasmashell to be ready ───────────────────────────────────────
for i in $(seq 1 30); do
    if $DBUS_CMD org.kde.plasmashell /PlasmaShell \
            org.kde.PlasmaShell.evaluateScript "print('ok');" 2>/dev/null \
            | grep -q 'ok'; then
        break
    fi
    sleep 1
done
sleep 4   # extra time for applets (including Panel Colorizer) to fully initialise

# ── Locate top panel ───────────────────────────────────────────────────────
TOP_ID=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var t=panelIds.filter(function(id){return panelById(id)&&panelById(id).location==='top';}); print(t[t.length-1]);" \
    2>/dev/null | tail -1)
[[ "${TOP_ID:-}" =~ ^[0-9]+$ ]] || { echo "apply-panel-colorizer: top panel not found" >&2; exit 1; }

# ── Locate Panel Colorizer applet ──────────────────────────────────────────
PC_ID=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var p=panelById(${TOP_ID}); var ws=p.widgets(['luisbocanegra.panel.colorizer']); print(ws.length>0?ws[0].id:'NOT_FOUND');" \
    2>/dev/null | tail -1)
[[ "${PC_ID:-}" =~ ^[0-9]+$ ]] || { echo "apply-panel-colorizer: Panel Colorizer not found" >&2; exit 1; }

# ── Locate spacers ─────────────────────────────────────────────────────────
SPACER_IDS_JSON=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var p=panelById(${TOP_ID}); var ws=p.widgets(['org.kde.plasma.panelspacer']); var ids=[]; ws.forEach(function(w){ids.push(w.id);}); print(JSON.stringify(ids));" \
    2>/dev/null | tail -1)

TOP_WIDGETS_JSON=$($DBUS_CMD org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var p=panelById(${TOP_ID}); var ws=p.widgets(); var out=[]; ws.forEach(function(w){out.push({id:w.id,name:w.type});}); print(JSON.stringify(out));" \
    2>/dev/null | tail -1)

# ── Apply Mocha config via JS writeConfig (fires configChanged immediately) ─
PANEL_ID="$TOP_ID" \
APPLET_ID="$PC_ID" \
PRESET_FILE="${PRESET_FILE}" \
SPACER_IDS_JSON="${SPACER_IDS_JSON:-[]}" \
TOP_WIDGETS_JSON="${TOP_WIDGETS_JSON:-[]}" \
python3 << 'PYEOF'
import os, json, re, subprocess, sys

preset_file = os.environ['PRESET_FILE']
top_id      = os.environ['PANEL_ID']
pc_id       = os.environ['APPLET_ID']
spacer_ids  = json.loads(os.environ.get('SPACER_IDS_JSON', '[]'))
top_widgets = json.loads(os.environ.get('TOP_WIDGETS_JSON', '[]'))

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
    return {
        "disabledFallback": True,
        "normal": {
            "enabled": True,
            "backgroundColor": {
                "enabled": True,
                "sourceType": 0,
                "custom": bg_hex,
                "alpha": 1,
            },
            "foregroundColor": {
                "enabled": True,
                "sourceType": 0,
                "custom": fg_hex,
                "alpha": 1,
            },
        },
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
    "  print('Panel Colorizer Mocha applied id='+w.id);"
    "}else{ print('WARNING: Panel Colorizer not found'); }"
)
result = subprocess.run(
    [dbus_cmd, 'org.kde.plasmashell', '/PlasmaShell',
     'org.kde.PlasmaShell.evaluateScript', js_code],
    capture_output=True, text=True
)
if result.stdout.strip():
    print(result.stdout.strip())
if result.returncode != 0:
    print(f"WARNING: JS config failed: {result.stderr.strip()}", file=sys.stderr)
PYEOF
