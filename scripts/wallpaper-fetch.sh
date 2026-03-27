#!/usr/bin/env bash
# wallpaper-fetch.sh — Download/update the wallpaper pool for matugen rotation.
#
# Sources:
#   1. Wallhaven (minimalism + landscape, dark backgrounds) via whdl
#   2. DenverCoder1/minimalistic-wallpaper-collection (git, MIT)
#   3. D3Ext/aesthetic-wallpapers (git, MIT)
#
# Pool location: ~/.local/share/wallpapers/ricing/
# Safe to re-run: git sources pull, whdl skips existing files.

set -euo pipefail

WALL_DIR="${MATUGEN_WALL_DIR:-${HOME}/.local/share/wallpapers/ricing}"
WHDL_BIN="${HOME}/.local/bin/whdl"

info()  { echo -e "\033[1;34m==>\033[0m $*"; }
ok()    { echo -e "\033[1;32m OK\033[0m $*"; }
warn()  { echo -e "\033[1;33mWRN\033[0m $*"; }
skip()  { echo -e "\033[1;36mSKP\033[0m $*"; }

mkdir -p "$WALL_DIR"

# ── Source 1: DenverCoder1/minimalistic-wallpaper-collection ──────────────────
# ~300+ minimal/flat wallpapers, no anime, MIT license.
info "Source: DenverCoder1/minimalistic-wallpaper-collection"
DENVER_DIR="${WALL_DIR}/minimalistic-wallpaper-collection"
if [[ -d "${DENVER_DIR}/.git" ]]; then
  git -C "$DENVER_DIR" pull --ff-only --quiet 2>/dev/null \
    && ok "minimalistic-wallpaper-collection updated" \
    || warn "Could not pull minimalistic-wallpaper-collection (offline?)"
else
  git clone --depth=1 --quiet \
    https://github.com/DenverCoder1/minimalistic-wallpaper-collection.git \
    "$DENVER_DIR" \
    && ok "minimalistic-wallpaper-collection cloned"
fi

# ── Source 2: D3Ext/aesthetic-wallpapers ─────────────────────────────────────
# 3k+ stars, MIT, community-curated from Wallhaven/Reddit/unixporn.
info "Source: D3Ext/aesthetic-wallpapers"
D3EXT_DIR="${WALL_DIR}/aesthetic-wallpapers"
if [[ -d "${D3EXT_DIR}/.git" ]]; then
  git -C "$D3EXT_DIR" pull --ff-only --quiet 2>/dev/null \
    && ok "aesthetic-wallpapers updated" \
    || warn "Could not pull aesthetic-wallpapers (offline?)"
else
  git clone --depth=1 --quiet \
    https://github.com/D3Ext/aesthetic-wallpapers.git \
    "$D3EXT_DIR" \
    && ok "aesthetic-wallpapers cloned"
fi

# ── Source 3: Wallhaven via whdl ─────────────────────────────────────────────
# categories=100 → General only (no anime, no people)
# purity=100 → SFW only
# Wallhaven color "1b1b1b" selects near-black backgrounds (dark wallpapers).
if [[ ! -x "$WHDL_BIN" ]]; then
  warn "whdl not found at ${WHDL_BIN} — skipping Wallhaven download."
  warn "Re-run setup.sh (Phase 1e) to install whdl, then re-run this script."
else
  WALLHAVEN_DIR="${WALL_DIR}/wallhaven"
  mkdir -p "$WALLHAVEN_DIR"

  # Tag 2278 = Minimalism
  info "Wallhaven: minimalism (dark, general, SFW)"
  "$WHDL_BIN" \
    --query "id:2278" \
    --categories 100 \
    --purity 100 \
    --sorting toplist \
    --count 200 \
    --output "${WALLHAVEN_DIR}/minimalism" \
    2>/dev/null \
    && ok "Wallhaven minimalism downloaded" \
    || warn "Wallhaven minimalism download failed (API rate limit or network issue)"

  # Tag 711 = Landscape
  info "Wallhaven: landscape (dark, general, SFW)"
  "$WHDL_BIN" \
    --query "id:711" \
    --categories 100 \
    --purity 100 \
    --sorting toplist \
    --count 200 \
    --output "${WALLHAVEN_DIR}/landscape" \
    2>/dev/null \
    && ok "Wallhaven landscape downloaded" \
    || warn "Wallhaven landscape download failed (API rate limit or network issue)"

  # Abstract / dark
  info "Wallhaven: abstract dark"
  "$WHDL_BIN" \
    --query "abstract dark" \
    --categories 100 \
    --purity 100 \
    --sorting toplist \
    --count 100 \
    --output "${WALLHAVEN_DIR}/abstract" \
    2>/dev/null \
    && ok "Wallhaven abstract downloaded" \
    || warn "Wallhaven abstract download failed"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL="$(find "$WALL_DIR" -type f \
  \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
  ! -iname '*-preview.*' | wc -l)"
ok "Wallpaper pool ready: ${WALL_DIR}"
ok "Total images: ${TOTAL}"
