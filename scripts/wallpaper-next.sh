#!/usr/bin/env bash
# wallpaper-next.sh — Pick a random wallpaper and set it in KDE Plasma.
# Uses the setWallpaper D-Bus method (not evaluateScript) so the
# wallpaperChanged signal fires; wallpaper-watcher.service picks that up
# and calls wallpaper-apply.sh to run matugen + live-reload all components.
#
# Usage:
#   wallpaper-next.sh              (normal invocation — from systemd timer)
#   wallpaper-next.sh --first-login (skips session guard; applies theme directly
#                                    in case wallpaper-watcher is not yet running)
#
# Dependencies: python3, python3-dbus

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# shellcheck disable=SC1091
source "${LIB_DIR}/theme-common.sh"

# ── Paths ─────────────────────────────────────────────────────────────────────
WALL_DIR="${MATUGEN_WALL_DIR:-${HOME}/.local/share/wallpapers/ricing}"
STATE_DIR="${HOME}/.local/state"
STATE_FILE="${STATE_DIR}/wallpaper-current"
STATE_JSON="${STATE_DIR}/wallpaper-next-state.json"
# ── Flags ─────────────────────────────────────────────────────────────────────
FIRST_LOGIN=0
for _arg in "$@"; do
  [[ "$_arg" == "--first-login" ]] && FIRST_LOGIN=1
done

# ── Session guard ─────────────────────────────────────────────────────────────
# Require a running Plasma session for D-Bus calls (skip on --first-login
# since setup-first-login.sh already waits for plasmashell).
if [[ "$FIRST_LOGIN" -eq 0 ]]; then
  if [[ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    theme_err "No Plasma session detected (WAYLAND_DISPLAY/DISPLAY unset). Exiting."
    exit 1
  fi
fi

# ── Sanity checks ─────────────────────────────────────────────────────────────
if [[ ! -x "$MATUGEN_BIN" ]]; then
  theme_err "matugen not found at ${MATUGEN_BIN}."
  theme_err "Re-run setup.sh (Phase 1e) or: curl -L <release> -o ~/.local/bin/matugen && chmod +x $_"
  exit 1
fi

if [[ ! -d "$WALL_DIR" ]]; then
  theme_err "Wallpaper pool directory not found: ${WALL_DIR}"
  theme_err "Run scripts/wallpaper-fetch.sh to download the wallpaper pool."
  exit 1
fi

# ── Pick wallpaper ─────────────────────────────────────────────────────────────
mapfile -t ALL_WALLS < <(
  find "$WALL_DIR" -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    ! -iname '*-preview.*' \
  | sort
)

if [[ "${#ALL_WALLS[@]}" -eq 0 ]]; then
  theme_err "No wallpapers found in ${WALL_DIR}."
  theme_err "Run scripts/wallpaper-fetch.sh to download the wallpaper pool."
  exit 1
fi

LAST_WALL="$(cat "$STATE_FILE" 2>/dev/null || true)"

# Shuffle candidates; exclude last shown if pool > 1
mapfile -t CANDIDATES < <(printf '%s\n' "${ALL_WALLS[@]}" | shuf)
NEXT_WALL=""
for _w in "${CANDIDATES[@]}"; do
  if [[ "$_w" != "$LAST_WALL" ]] || [[ "${#ALL_WALLS[@]}" -eq 1 ]]; then
    NEXT_WALL="$_w"
    break
  fi
done
[[ -z "$NEXT_WALL" ]] && NEXT_WALL="${CANDIDATES[0]}"

theme_info "Wallpaper: ${NEXT_WALL}"

# ── Set wallpaper in Plasma ───────────────────────────────────────────────────
# setWallpaper (unlike evaluateScript) emits the wallpaperChanged D-Bus signal,
# which wallpaper-watcher.service catches to trigger matugen + theme reload.
# Loop over all screens so multi-monitor setups are fully covered.
python3 - "$NEXT_WALL" <<'PY' || theme_warn "Plasma D-Bus setWallpaper failed (session may not be ready)"
import dbus, sys
wall = sys.argv[1]
bus = dbus.SessionBus()
iface = dbus.Interface(
    bus.get_object("org.kde.plasmashell", "/PlasmaShell"),
    "org.kde.PlasmaShell",
)
screen = 0
while True:
    try:
        iface.setWallpaper("org.kde.image", {"Image": wall}, dbus.UInt32(screen))
        screen += 1
    except dbus.DBusException:
        break
sys.exit(0 if screen > 0 else 1)
PY

theme_info "Wallpaper set in Plasma"

# ── Save state ────────────────────────────────────────────────────────────────
mkdir -p "$STATE_DIR"
echo "$NEXT_WALL" > "$STATE_FILE"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$NEXT_WALL" "$TIMESTAMP" "$STATE_JSON" <<'PY'
import json, sys
wall, ts, out = sys.argv[1:]
with open(out, "w", encoding="utf-8") as f:
    json.dump({"wallpaper": wall, "timestamp": ts}, f, indent=2)
PY

theme_info "State saved to ${STATE_JSON}"

# ── Apply theme on first login ────────────────────────────────────────────────
# On normal runs wallpaper-watcher.service catches the wallpaperChanged signal
# and calls wallpaper-apply.sh. On --first-login the service may not yet be
# running (race with graphical-session.target), so we call it directly.
if [[ "$FIRST_LOGIN" -eq 1 ]]; then
  theme_info "First login: applying theme directly"
  bash "${SCRIPT_DIR}/wallpaper-apply.sh" --wallpaper "$NEXT_WALL" \
    || theme_warn "wallpaper-apply.sh failed on first login"
fi

theme_info "Done."
