#!/usr/bin/env bash
# apply-wallpaper-rotation.sh â€” Configure KDE desktop slideshow wallpaper.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WALLPAPER_ROOT_DIR="${REPO_DIR}/images/wallpaper-rotation"
THEME_STATE_FILE="${THEME_STATE_FILE:-$HOME/.config/linux-setup/theme-state.json}"
WALLPAPER_SET="${WALLPAPER_SET:-}"
SLIDE_INTERVAL_SECONDS="${SLIDE_INTERVAL_SECONDS:-7200}"

# Resolve active theme from --theme arg if WALLPAPER_SET not set via env
if [[ -z "$WALLPAPER_SET" ]]; then
  for _arg in "$@"; do
    case "$_arg" in
      --theme=*) WALLPAPER_SET="${_arg#--theme=}" ;;
    esac
  done
fi

if ! [[ -d "$WALLPAPER_ROOT_DIR" ]]; then
  echo "Wallpaper directory not found: $WALLPAPER_ROOT_DIR" >&2
  exit 1
fi

if [[ -z "$WALLPAPER_SET" && -f "$THEME_STATE_FILE" ]]; then
  WALLPAPER_SET="$(python3 - "$THEME_STATE_FILE" <<'PY'
import json
import sys
from pathlib import Path

state_file = Path(sys.argv[1])
try:
    payload = json.loads(state_file.read_text(encoding="utf-8"))
except Exception:
    print("")
    raise SystemExit(0)

print(payload.get("theme", ""))
PY
)"
fi

WALLPAPER_DIR="$WALLPAPER_ROOT_DIR"
if [[ -n "$WALLPAPER_SET" && -d "$WALLPAPER_ROOT_DIR/$WALLPAPER_SET" ]]; then
  WALLPAPER_DIR="$WALLPAPER_ROOT_DIR/$WALLPAPER_SET"
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

echo "KDE wallpaper slideshow configured (theme: ${WALLPAPER_SET:-default}, dir: $WALLPAPER_DIR)"
