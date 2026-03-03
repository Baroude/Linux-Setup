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

# ── Apply Mocha config via JS writeConfig (fires configChanged immediately) ─
PANEL_ID="$TOP_ID" \
APPLET_ID="$PC_ID" \
PRESET_FILE="${PRESET_FILE}" \
SPACER_IDS_JSON="${SPACER_IDS_JSON:-[]}" \
python3 << 'PYEOF'
import os, json, subprocess

preset_file = os.environ['PRESET_FILE']
top_id      = os.environ['PANEL_ID']
pc_id       = os.environ['APPLET_ID']
spacer_ids  = json.loads(os.environ.get('SPACER_IDS_JSON', '[]'))

with open(preset_file) as f:
    preset = json.load(f)
gs = preset['globalSettings']
gs['unifiedBackground'] = []
gs_str = json.dumps(gs, separators=(',', ':'))

off = {
    "disabledFallback": True,
    "normal": {"enabled": False}, "busy": {"enabled": False},
    "hovered": {"enabled": False}, "needsAttention": {"enabled": False},
    "expanded": {"enabled": False},
}
co = {
    "overrides": {"spacer_off": off},
    "associations": (
        [{"id": -1, "name": "org.kde.plasma.panelspacer", "presets": ["spacer_off"]}]
        + [{"id": int(sid), "name": "org.kde.plasma.panelspacer",
            "presets": ["spacer_off"]} for sid in spacer_ids]
    ),
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
