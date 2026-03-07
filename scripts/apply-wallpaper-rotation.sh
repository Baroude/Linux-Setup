#!/usr/bin/env bash
# apply-wallpaper-rotation.sh — Configure KDE desktop slideshow wallpaper.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SLIDE_INTERVAL_SECONDS="${SLIDE_INTERVAL_SECONDS:-7200}"

# Resolve active theme: prefer --theme arg, then theme-state.json, then "catppuccin"
_active_theme=""
for _arg in "$@"; do
  case "$_arg" in
    --theme=*) _active_theme="${_arg#--theme=}" ;;
  esac
done
if [[ -z "$_active_theme" ]]; then
  _state_file="${HOME}/.config/linux-setup/theme-state.json"
  if [[ -f "$_state_file" ]]; then
    _active_theme="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['theme'])" \
      "$_state_file" 2>/dev/null)" || _active_theme=""
  fi
fi
_active_theme="${_active_theme:-catppuccin}"

# Use theme-specific subfolder if it exists, otherwise fall back to rotation root
_theme_dir="${REPO_DIR}/images/wallpaper-rotation/${_active_theme}"
if [[ -d "$_theme_dir" ]]; then
  WALLPAPER_DIR="$_theme_dir"
else
  WALLPAPER_DIR="${REPO_DIR}/images/wallpaper-rotation"
fi

if ! [[ -d "$WALLPAPER_DIR" ]]; then
  echo "Wallpaper directory not found: $WALLPAPER_DIR" >&2
  exit 1
fi

if command -v qdbus6 >/dev/null 2>&1; then
  QDBUS_BIN="qdbus6"
elif command -v qdbus >/dev/null 2>&1; then
  QDBUS_BIN="qdbus"
else
  echo "qdbus/qdbus6 not found; cannot configure Plasma wallpaper slideshow." >&2
  exit 1
fi

first_image="$(
  find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    | sort \
    | head -n 1
)"

if [[ -z "$first_image" ]]; then
  echo "No wallpapers found in $WALLPAPER_DIR" >&2
  exit 1
fi

wallpaper_dir_abs="$(python3 - "$WALLPAPER_DIR" <<'PY'
from pathlib import Path
import sys
print(str(Path(sys.argv[1]).resolve()))
PY
)"

first_image_uri="$(python3 - "$first_image" <<'PY'
from pathlib import Path
import sys
print(Path(sys.argv[1]).resolve().as_uri())
PY
)"

js_script="$(python3 - "$wallpaper_dir_abs" "$first_image_uri" "$SLIDE_INTERVAL_SECONDS" <<'PY'
import json
import sys

wall_dir, first_uri, interval = sys.argv[1:]
print(
    "var desktopsList = desktops();"
    "for (var i = 0; i < desktopsList.length; i++) {"
    "  var d = desktopsList[i];"
    "  d.wallpaperPlugin = \"org.kde.slideshow\";"
    "  d.currentConfigGroup = Array(\"Wallpaper\", \"org.kde.slideshow\", \"General\");"
    f"  d.writeConfig(\"SlidePaths\", {json.dumps(wall_dir)});"
    f"  d.writeConfig(\"SlideInterval\", Number({json.dumps(interval)}));"
    "  d.writeConfig(\"Randomize\", true);"
    f"  d.writeConfig(\"Image\", {json.dumps(first_uri)});"
    "}"
)
PY
)"

"$QDBUS_BIN" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$js_script" >/dev/null

echo "KDE wallpaper slideshow configured (theme: ${_active_theme}, dir: $WALLPAPER_DIR)"
