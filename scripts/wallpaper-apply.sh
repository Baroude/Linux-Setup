#!/usr/bin/env bash
# wallpaper-apply.sh — Run matugen on the current KDE wallpaper and live-reload
# all themed components (KDE color scheme, kitty, Panel Colorizer, btop, SDDM).
#
# Called by kde-material-you-colors as on_change_hook (no args), or directly:
#   wallpaper-apply.sh                     (reads wallpaper from Plasma config)
#   wallpaper-apply.sh --wallpaper <path>  (use explicit path)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# shellcheck disable=SC1091
source "${LIB_DIR}/theme-common.sh"
# shellcheck disable=SC1091
source "${LIB_DIR}/theme-apply-panel.sh"

MATUGEN_BIN="${HOME}/.local/bin/matugen"
MATUGEN_CFG="${REPO_DIR}/themes/matugen/config.toml"
MATUGEN_CACHE="${HOME}/.cache/matugen"

# ── Parse args ────────────────────────────────────────────────────────────────
WALL_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --wallpaper) WALL_PATH="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# ── Get wallpaper path from Plasma config if not provided ─────────────────────
if [[ -z "$WALL_PATH" ]]; then
  WALL_PATH="$(python3 -c "
from urllib.parse import unquote
import re, os
conf = os.path.expanduser('~/.config/plasma-org.kde.plasma.desktop-appletsrc')
with open(conf) as f:
    content = f.read()
m = re.search(r'Image=file://([^\n,]+)', content)
print(unquote(m.group(1).strip()) if m else '')
" 2>/dev/null)"
fi

if [[ -z "$WALL_PATH" || ! -f "$WALL_PATH" ]]; then
  theme_err "Could not determine current wallpaper path (got: '${WALL_PATH}')"
  exit 1
fi

theme_info "Applying theme for: ${WALL_PATH}"

# ── Sanity check ──────────────────────────────────────────────────────────────
if [[ ! -x "$MATUGEN_BIN" ]]; then
  theme_err "matugen not found at ${MATUGEN_BIN}"
  exit 1
fi

# ── Run matugen ───────────────────────────────────────────────────────────────
mkdir -p "$MATUGEN_CACHE"

# matugen resolves template input_path relative to CWD → run from repo root
(
  cd "$REPO_DIR"
  "$MATUGEN_BIN" image "$WALL_PATH" --config "$MATUGEN_CFG"
) || { theme_err "matugen failed — theming aborted"; exit 1; }

theme_info "matugen palette generated"

# ── Apply KDE color scheme ────────────────────────────────────────────────────
if command -v plasma-apply-colorscheme &>/dev/null; then
  plasma-apply-colorscheme MatugenDynamic 2>/dev/null \
    || theme_warn "plasma-apply-colorscheme failed (scheme may need one login first)"
  theme_info "KDE color scheme: MatugenDynamic"
fi

# ── Reload kitty ──────────────────────────────────────────────────────────────
pkill -USR1 kitty 2>/dev/null || true
theme_info "kitty reloaded"

# ── Reload Panel Colorizer ────────────────────────────────────────────────────
PANEL_PRESET_FILE="${HOME}/.config/linux-setup/panel-colorizer-global.json"
if [[ -f "$PANEL_PRESET_FILE" ]]; then
  export PANEL_PRESET_FILE
  export PANEL_WIDGET_COLORS_JSON="{}"
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
  theme_info "btop: color_theme → matugen"
fi

# ── Update SDDM theme.conf.user (needs sudo) ──────────────────────────────────
_reload_sddm() {
  local staging="${MATUGEN_CACHE}/sddm-theme.conf"
  local sddm_sys_conf="/etc/sddm.conf.d/10-theme.conf"

  [[ -f "$staging" ]] || { theme_warn "SDDM: staging file missing — skipping"; return 0; }
  [[ -f "$sddm_sys_conf" ]] || { theme_warn "SDDM: not configured — skipping"; return 0; }

  local theme_name
  theme_name="$(grep '^Current=' "$sddm_sys_conf" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]')"
  [[ -z "$theme_name" ]] && { theme_warn "SDDM: Current= not found — skipping"; return 0; }

  local dest="/usr/share/sddm/themes/${theme_name}/theme.conf.user"
  if sudo install -m 644 "$staging" "$dest" 2>/dev/null; then
    theme_info "SDDM theme.conf.user updated (${theme_name})"
  else
    theme_warn "SDDM: sudo install failed — check /etc/sudoers.d/99-wallpaper-sddm"
  fi
}
_reload_sddm

theme_info "Done."
