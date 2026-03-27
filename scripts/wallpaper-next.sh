#!/usr/bin/env bash
# wallpaper-next.sh — Pick a random dark wallpaper, set it in KDE Plasma,
# run matugen to generate a dynamic color palette, then live-reload all
# themed components (kitty, KDE color scheme, Panel Colorizer, btop, SDDM…).
#
# Usage:
#   wallpaper-next.sh              (normal invocation — from systemd timer)
#   wallpaper-next.sh --first-login (called by setup-first-login.sh; skips session guard)
#
# Dependencies: matugen (~/.local/bin/matugen), qdbus6 or qdbus,
#               plasma-apply-colorscheme, kvantummanager, kitty (optional),
#               python3-websockets + cava (for Kurve widget, already installed)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# shellcheck disable=SC1091
source "${LIB_DIR}/theme-common.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/theme-apply-panel.sh"

# ── Paths ─────────────────────────────────────────────────────────────────────
WALL_DIR="${MATUGEN_WALL_DIR:-${HOME}/.local/share/wallpapers/ricing}"
STATE_DIR="${HOME}/.local/state"
STATE_FILE="${STATE_DIR}/wallpaper-current"
STATE_JSON="${STATE_DIR}/wallpaper-next-state.json"
MATUGEN_BIN="${HOME}/.local/bin/matugen"
MATUGEN_CFG="${REPO_DIR}/themes/matugen/config.toml"
MATUGEN_CACHE="${HOME}/.cache/matugen"

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
WALL_URI="$(python3 -c "from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())" "$NEXT_WALL")"

DBUS_CMD="$(_theme_panel_dbus_cmd)"

"$DBUS_CMD" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  "var desktopsList = desktops();
   for (var i = 0; i < desktopsList.length; i++) {
     var d = desktopsList[i];
     d.wallpaperPlugin = 'org.kde.image';
     d.currentConfigGroup = Array('Wallpaper', 'org.kde.image', 'General');
     d.writeConfig('Image', '${WALL_URI}');
   }" >/dev/null 2>&1 || theme_warn "Plasma D-Bus wallpaper set failed (session may not be ready)"

theme_info "Wallpaper set in Plasma"

# ── Run matugen ───────────────────────────────────────────────────────────────
mkdir -p "$MATUGEN_CACHE"

# matugen resolves template input_path relative to CWD → run from repo root
(
  cd "$REPO_DIR"
  "$MATUGEN_BIN" image "$NEXT_WALL" --config "$MATUGEN_CFG"
) || { theme_err "matugen failed — theming aborted"; exit 1; }

theme_info "matugen palette generated"

# ── Apply KDE color scheme ────────────────────────────────────────────────────
if command -v plasma-apply-colorscheme &>/dev/null; then
  plasma-apply-colorscheme MatugenDynamic 2>/dev/null \
    || theme_warn "plasma-apply-colorscheme failed (scheme may need one login first)"
  theme_info "KDE color scheme: MatugenDynamic"
fi

# ── Reload kitty ──────────────────────────────────────────────────────────────
# SIGUSR1 triggers kitty to reload kitty.conf (which includes theme.conf).
pkill -USR1 kitty 2>/dev/null || true
theme_info "kitty reloaded"

# ── Reload Panel Colorizer ────────────────────────────────────────────────────
# matugen already wrote the new panel-colorizer-global.json.
# Reuse theme_panel_apply_live from theme-apply-panel.sh with the rendered file.
PANEL_PRESET_FILE="${HOME}/.config/linux-setup/panel-colorizer-global.json"
if [[ -f "$PANEL_PRESET_FILE" ]]; then
  export PANEL_PRESET_FILE
  export PANEL_WIDGET_COLORS_JSON="{}"  # per-widget overrides handled by the preset file
  if theme_apply_panel_adapter 2>/dev/null; then
    theme_info "Panel Colorizer reloaded"
  else
    theme_warn "Panel Colorizer reload deferred (applet not ready)"
  fi
fi

# ── Update btop color_theme ───────────────────────────────────────────────────
BTOP_CONF="${HOME}/.config/btop/btop.conf"
if [[ -f "$BTOP_CONF" ]]; then
  if grep -q '^color_theme' "$BTOP_CONF"; then
    sed -i -E 's|^color_theme\s*=.*|color_theme = "matugen"|' "$BTOP_CONF"
  else
    printf '\ncolor_theme = "matugen"\ntheme_background = False\n' >> "$BTOP_CONF"
  fi
  theme_info "btop: color_theme set to matugen"
fi

# ── Update SDDM theme.conf.user (needs sudo) ──────────────────────────────────
# matugen writes the rendered config to ~/.cache/matugen/sddm-theme.conf.
# A narrow sudoers rule (written by setup.sh Phase 14e) allows passwordless
# `sudo install` to the SDDM theme directory only.
_reload_sddm() {
  local staging="${MATUGEN_CACHE}/sddm-theme.conf"
  local sddm_sys_conf="/etc/sddm.conf.d/10-theme.conf"

  [[ -f "$staging" ]] || { theme_warn "SDDM: staging file missing — skipping"; return 0; }
  [[ -f "$sddm_sys_conf" ]] || { theme_warn "SDDM: not configured at ${sddm_sys_conf} — skipping"; return 0; }

  local theme_name
  theme_name="$(grep '^Current=' "$sddm_sys_conf" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"
  if [[ -z "$theme_name" ]]; then
    theme_warn "SDDM: Current= not found in ${sddm_sys_conf} — skipping"
    return 0
  fi

  local dest="/usr/share/sddm/themes/${theme_name}/theme.conf.user"
  if sudo install -m 644 "$staging" "$dest" 2>/dev/null; then
    theme_info "SDDM theme.conf.user updated (${theme_name})"
  else
    theme_warn "SDDM: sudo install failed — check /etc/sudoers.d/99-wallpaper-sddm"
  fi
}
_reload_sddm

# ── Save state ────────────────────────────────────────────────────────────────
mkdir -p "$STATE_DIR"
echo "$NEXT_WALL" > "$STATE_FILE"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
python3 - "$NEXT_WALL" "$TIMESTAMP" "$STATE_JSON" <<'PY'
import json, sys
wall, ts, out = sys.argv[1:]
with open(out, "w", encoding="utf-8") as f:
    json.dump({"wallpaper": wall, "timestamp": ts, "matugen_ok": True}, f, indent=2)
PY

theme_info "Done. State saved to ${STATE_JSON}"
