#!/usr/bin/env bash
# configure-rofi-shortcut.sh
# Registers a global KDE shortcut for rofi after checking existing mappings.

set -euo pipefail

info() { printf '[rofi-shortcut] %s\n' "$*"; }
warn() { printf '[rofi-shortcut] WARN: %s\n' "$*" >&2; }

KGLOBAL_FILE="$HOME/.config/kglobalshortcutsrc"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="${DESKTOP_DIR}/rofi-app-launcher.desktop"
ROFI_GROUP="rofi-app-launcher.desktop"
ROFI_SERVICE_GROUP="services/${ROFI_GROUP}"

if ! command -v kwriteconfig6 >/dev/null 2>&1; then
  warn "kwriteconfig6 not found; cannot configure KDE shortcut."
  exit 0
fi

mkdir -p "$HOME/.config" "$DESKTOP_DIR"
[[ -f "$KGLOBAL_FILE" ]] || : > "$KGLOBAL_FILE"

analysis_file="$(mktemp)"
python3 - "$KGLOBAL_FILE" > "$analysis_file" <<'PY'
import json
import sys
from pathlib import Path

cfg_path = Path(sys.argv[1])

entries = []
group = ""
for raw in cfg_path.read_text(encoding="utf-8", errors="ignore").splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or line.startswith(";"):
        continue
    if line.startswith("[") and line.endswith("]"):
        group = line[1:-1].strip()
        continue
    if "=" not in raw:
        continue
    key, value = raw.split("=", 1)
    key = key.strip()
    parts = [p.strip() for p in value.split(",")]
    for idx in (0, 1):
        if idx >= len(parts):
            continue
        shortcut = parts[idx].strip()
        if not shortcut or shortcut.lower() == "none":
            continue
        entries.append(
            {
                "group": group,
                "key": key,
                "shortcut": shortcut,
            }
        )


def norm(value: str) -> str:
    return "".join(value.lower().split())


def owners(shortcut: str):
    n = norm(shortcut)
    return [e for e in entries if norm(e["shortcut"]) == n]


candidates = ["Meta+Space", "Meta+R", "Meta+/", "Alt+Space"]
rofi_groups = {"rofi-app-launcher.desktop"}
krunner_groups = {"krunner", "org.kde.krunner.desktop", "services/org.kde.krunner.desktop"}

chosen = ""
reason = ""
for cand in candidates:
    hit_list = owners(cand)
    hit_groups = {h["group"].lower() for h in hit_list}

    if not hit_list or hit_groups.issubset(rofi_groups):
        chosen = cand
        reason = "free"
        break

    if cand == "Meta+Space" and hit_groups.issubset(rofi_groups | krunner_groups):
        chosen = cand
        reason = "krunner"
        break

meta_space_hits = owners("Meta+Space")
disable_krunner = (
    chosen == "Meta+Space"
    and any(h["group"].lower() in krunner_groups for h in meta_space_hits)
)

meta_shortcuts = [
    e for e in entries if "meta+" in norm(e["shortcut"])
]
meta_shortcuts.sort(key=lambda e: (norm(e["shortcut"]), e["group"], e["key"]))

out = {
    "chosen": chosen,
    "reason": reason,
    "disable_krunner": disable_krunner,
    "candidates": [{"shortcut": c, "hits": owners(c)} for c in candidates],
    "meta_shortcuts": meta_shortcuts,
}
print(json.dumps(out))
PY

info "Scanning existing KDE global shortcuts in ${KGLOBAL_FILE}"
python3 - "$analysis_file" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
meta = data["meta_shortcuts"]

if not meta:
    print("[rofi-shortcut] No existing Meta-based global shortcuts found.")
else:
    print("[rofi-shortcut] Existing Meta-based shortcuts:")
    for entry in meta:
        print(
            f"[rofi-shortcut]   {entry['shortcut']:<16} -> "
            f"[{entry['group']}] {entry['key']}"
        )

print("[rofi-shortcut] Candidate availability:")
for cand in data["candidates"]:
    shortcut = cand["shortcut"]
    hits = cand["hits"]
    if not hits:
        print(f"[rofi-shortcut]   {shortcut:<10} : available")
        continue
    owners = ", ".join(f"[{h['group']}] {h['key']}" for h in hits)
    print(f"[rofi-shortcut]   {shortcut:<10} : in use by {owners}")
PY

chosen_shortcut="$(python3 - "$analysis_file" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["chosen"])
PY
)"

disable_krunner="$(python3 - "$analysis_file" <<'PY'
import json
import sys
print("1" if json.load(open(sys.argv[1], encoding="utf-8"))["disable_krunner"] else "0")
PY
)"

rm -f "$analysis_file"

launcher_icon="system-run"
if [[ -f "$HOME/.local/share/icons/catppuccin-vibes/apps-vibrant.svg" ]]; then
  launcher_icon="$HOME/.local/share/icons/catppuccin-vibes/apps-vibrant.svg"
fi

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Rofi Application Launcher
Comment=Launch applications with rofi
Exec=rofi -show drun
Icon=${launcher_icon}
Terminal=false
Categories=Utility;
StartupNotify=false
EOF

if command -v kbuildsycoca6 >/dev/null 2>&1; then
  kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
fi

if [[ -z "$chosen_shortcut" ]]; then
  warn "No safe shortcut candidate available (Meta+Space, Meta+R, Meta+/, Alt+Space)."
  warn "Rofi launcher desktop entry was created, but no global keybinding was changed."
  exit 0
fi

kwriteconfig6 --file "$KGLOBAL_FILE" \
  --group "$ROFI_GROUP" \
  --key "_launch" \
  "${chosen_shortcut},${chosen_shortcut},Launch Rofi Application Launcher"
kwriteconfig6 --file "$KGLOBAL_FILE" \
  --group "$ROFI_SERVICE_GROUP" \
  --key "_launch" \
  "${chosen_shortcut},${chosen_shortcut},Launch Rofi Application Launcher"

# Keep desktop metadata aligned with the assigned shortcut so KDE can expose it in UI.
kwriteconfig6 --file "$DESKTOP_FILE" \
  --group "Desktop Entry" \
  --key "X-KDE-Shortcuts" \
  "${chosen_shortcut}"

if [[ "$disable_krunner" == "1" ]]; then
  for krunner_group in krunner org.kde.krunner.desktop services/org.kde.krunner.desktop; do
    krunner_value="$(kreadconfig6 --file "$KGLOBAL_FILE" --group "$krunner_group" --key _launch 2>/dev/null || true)"
    [[ -n "$krunner_value" ]] || continue
    IFS=',' read -r _krunner_primary krunner_secondary krunner_desc <<< "$krunner_value"
    krunner_secondary="${krunner_secondary:-Alt+F2}"
    krunner_desc="${krunner_desc:-Activate KRunner}"
    kwriteconfig6 --file "$KGLOBAL_FILE" \
      --group "$krunner_group" \
      --key _launch \
      "none,${krunner_secondary},${krunner_desc}"
  done
  info "Meta+Space reassigned from KRunner to rofi (KRunner secondary shortcut preserved)."
fi

refresh_global_shortcuts() {
  local bus_cmd=""
  if command -v qdbus6 >/dev/null 2>&1; then
    bus_cmd="qdbus6"
  elif command -v qdbus >/dev/null 2>&1; then
    bus_cmd="qdbus"
  fi

  if [[ -n "$bus_cmd" ]]; then
    "$bus_cmd" org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.reloadConfig >/dev/null 2>&1 && return 0
  fi

  if command -v kquitapp6 >/dev/null 2>&1; then
    kquitapp6 kglobalacceld >/dev/null 2>&1 || true
    sleep 0.4
    if command -v kglobalacceld6 >/dev/null 2>&1; then
      nohup kglobalacceld6 >/dev/null 2>&1 &
      return 0
    fi
    if command -v kglobalacceld >/dev/null 2>&1; then
      nohup kglobalacceld >/dev/null 2>&1 &
      return 0
    fi
  fi

  return 1
}

if refresh_global_shortcuts; then
  info "KDE global shortcut service refreshed."
else
  warn "Could not refresh kglobalaccel automatically; log out/in if shortcut does not apply immediately."
fi

info "Rofi launcher shortcut configured: ${chosen_shortcut}"
