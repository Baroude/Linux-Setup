#!/usr/bin/env python3

import copy
import json
import os
import re
import subprocess
import sys


def env_json(name, default):
    raw = os.environ.get(name)
    if not raw:
        return default
    return json.loads(raw)


preset_file = os.environ["PANEL_PRESET_FILE"]
top_id = os.environ["PANEL_ID"]
pc_id = os.environ["APPLET_ID"]
spacer_ids = env_json("SPACER_IDS_JSON", [])
top_widgets = env_json("TOP_WIDGETS_JSON", [])
widget_colors = env_json("PANEL_WIDGET_COLORS_JSON", {})
write_disk = os.environ.get("PANEL_WRITE_DISK", "0") == "1"
config_file = os.path.expanduser(os.environ.get(
    "PANEL_CONFIG_FILE",
    "~/.config/plasma-org.kde.plasma.desktop-appletsrc",
))
dbus_cmd = os.environ.get("DBUS_CMD", "qdbus6")

with open(preset_file, encoding="utf-8") as fh:
    preset = json.load(fh)

gs = preset["globalSettings"]
gs["unifiedBackground"] = []
widget_bg = gs.setdefault("widgets", {}).setdefault("normal", {}).setdefault("backgroundColor", {})
widget_bg["sourceType"] = 0
widget_bg["list"] = []
if "custom" not in widget_bg:
    widget_bg["custom"] = "#313244"
widget_bg["enabled"] = True

gs_str = json.dumps(gs, separators=(",", ":"))

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
co_str = json.dumps(co, separators=(",", ":"))

if write_disk:
    base = [
        "kwriteconfig6", "--file", config_file,
        "--group", "Containments", "--group", top_id,
        "--group", "Applets", "--group", pc_id,
        "--group", "Configuration", "--group", "General",
    ]
    subprocess.run(base + ["--key", "isEnabled", "true"], check=True)
    subprocess.run(base + ["--key", "hideWidget", "true"], check=True)
    subprocess.run(base + ["--key", "globalSettings", gs_str], check=True)
    subprocess.run(base + ["--key", "configurationOverrides", co_str], check=True)

js_gs = gs_str.replace("\\", "\\\\").replace("'", "\\'")
js_co = co_str.replace("\\", "\\\\").replace("'", "\\'")
js_code = (
    f"var p=panelById({top_id});"
    "var ws=p.widgets(['luisbocanegra.panel.colorizer']);"
    "if(ws.length>0){"
    "  var w=ws[0]; w.currentConfigGroup=['General'];"
    "  w.writeConfig('isEnabled','true');"
    "  w.writeConfig('hideWidget','true');"
    f"  w.writeConfig('globalSettings','{js_gs}');"
    f"  w.writeConfig('configurationOverrides','{js_co}');"
    "  print('Panel Colorizer applied id='+w.id);"
    "}else{ print('WARNING: Panel Colorizer not found'); }"
)
result = subprocess.run(
    [
        dbus_cmd,
        "org.kde.plasmashell",
        "/PlasmaShell",
        "org.kde.PlasmaShell.evaluateScript",
        js_code,
    ],
    capture_output=True,
    text=True,
)

if result.stdout.strip():
    print(result.stdout.strip())
if result.returncode != 0:
    print(f"WARNING: Panel Colorizer JS apply failed: {result.stderr.strip()}", file=sys.stderr)
    sys.exit(result.returncode)
