#!/usr/bin/env bash
# wallpaper-apply.sh — Run matugen on the current KDE wallpaper and live-reload
# all themed components (KDE color scheme, kitty, Panel Colorizer, btop, SDDM).
#
# Called by wallpaper-watcher.service on every wallpaperChanged D-Bus signal,
# or directly:
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
m = re.search(r'Image=(?:file://)?([^\n,]+)', content)
raw = m.group(1).strip() if m else ''
print(unquote(raw) if raw else '')
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
  "$MATUGEN_BIN" image "$WALL_PATH" --config "$MATUGEN_CFG" --source-color-index 0
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
# matugen already generated panel-colorizer-global.json; skip theme_apply_panel_adapter
# (which would overwrite it with the Catppuccin template via theme_panel_prepare_assets).
PALETTE_FILE="${HOME}/.cache/matugen/palette.json"
if [[ -f "$PALETTE_FILE" ]]; then
  # Build per-widget accent colors from the matugen palette.
  # Maps KDE widget type names → background hex; panel-colorizer-apply.py
  # derives a readable foreground from the global template's foregroundColor spec.
  THEME_PANEL_WIDGET_COLORS_JSON="$(python3 - "$PALETTE_FILE" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    p = json.load(f)
widget_colors = {
    "org.kde.plasma.pager":                [p["tertiary"],   p["on_tertiary"]],
    "org.kde.plasma.digitalclock":         [p["primary"],    p["on_primary"]],
    "org.kde.plasma.systemtray":           [p["primary"],    p["on_primary"]],
    "org.kde.plasma.appmenu":              [p["tertiary"],   p["on_tertiary"]],
    "org.kde.plasma.mediacontroller":      [p["primary"],    p["on_primary"]],
    "org.kde.plasma.weather":              [p["tertiary"],   p["on_tertiary"]],
    "org.kde.plasma.battery":              [p["tertiary"],   p["on_tertiary"]],
    "luisbocanegra.audio.visualizer":      [p["primary"],    p["on_primary"]],
    "com.github.antroids.application-title-bar": [p["tertiary"], p["on_tertiary"]],
    "org.kde.plasma.systemmonitor":        [p["primary"],    p["on_primary"]],
    "org.kde.plasma.lock_logout":          [p["tertiary"],   p["on_tertiary"]],
}
print(json.dumps(widget_colors))
PY
  )"
  export THEME_PANEL_WIDGET_COLORS_JSON
fi

if [[ -f "${HOME}/.config/linux-setup/panel-colorizer-global.json" ]]; then
  if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    theme_warn "No active desktop session detected; panel apply deferred"
  elif theme_panel_apply_live 0 2>/dev/null; then
    theme_info "Panel Colorizer reloaded"
  else
    theme_warn "Panel Colorizer reload deferred (applet not ready)"
  fi
fi

# ── Reload Papirus-Dark folder colors ────────────────────────────────────────
_reload_papirus() {
  local palette="${HOME}/.cache/matugen/palette.json"
  local papirus_bin="${HOME}/.local/bin/papirus-folders"
  local nearest_py="${SCRIPT_DIR}/lib/papirus-nearest-color.py"

  [[ -f "$palette" ]] || { theme_warn "Papirus: palette.json missing — skipping"; return 0; }
  [[ -x "$papirus_bin" ]] || { theme_warn "Papirus: papirus-folders not installed — skipping"; return 0; }
  [[ -f "$nearest_py" ]] || { theme_warn "Papirus: nearest-color script missing — skipping"; return 0; }

  local primary color_name
  primary="$(python3 -c "import json; print(json.load(open('$palette'))['primary'])" 2>/dev/null)"
  [[ -n "$primary" ]] || { theme_warn "Papirus: could not read primary color"; return 0; }

  color_name="$(python3 "$nearest_py" "$primary" 2>/dev/null)"
  [[ -n "$color_name" ]] || { theme_warn "Papirus: nearest-color returned empty"; return 0; }

  theme_info "Papirus folder color: ${primary} → ${color_name}"
  local ok=1
  sudo "$papirus_bin" -C "$color_name" -t Papirus-Dark --once 2>/dev/null || ok=0
  # Papirus-Dark inherits 32x32+ from base Papirus; update it too so all sizes match
  sudo "$papirus_bin" -C "$color_name" -t Papirus --once 2>/dev/null || true
  if [[ "$ok" -eq 1 ]]; then
    kbuildsycoca6 --noincremental 2>/dev/null || true
    theme_info "Papirus-Dark folder colors updated"
  else
    theme_warn "Papirus: papirus-folders failed (check sudoers rule)"
  fi
}
_reload_papirus

# ── Reload running nvim instances ────────────────────────────────────────────
_reload_nvim() {
  local nvim_colors="${HOME}/.config/nvim/colors/matugen.vim"
  [[ -f "$nvim_colors" ]] || return 0
  local found=0
  for _sock in /run/user/${UID}/nvim.*.0 /tmp/nvim*/nvim.*.0; do
    [[ -S "$_sock" ]] || continue
    nvim --server "$_sock" --remote-expr 'execute("colorscheme matugen")' 2>/dev/null &
    found=1
  done
  [[ "$found" -eq 1 ]] && theme_info "nvim colorscheme reloaded" || true
}
_reload_nvim

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
