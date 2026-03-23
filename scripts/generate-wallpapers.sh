#!/usr/bin/env bash
# generate-wallpapers.sh — Clone Sciwall and generate science-themed wallpapers.
#
# Clones https://github.com/Baroude/Sciwall to ~/.local/share/sciwall (or
# $SCIWALL_DIR), installs it into a venv, and runs the generator for the active
# theme.  Safe to re-run: --missing-only skips already-generated files.
#
# Usage:
#   ./generate-wallpapers.sh [--theme <sciwall-theme>] [--type <type>] [--preview]
#
# Theme resolution (first match wins):
#   1. --theme flag
#   2. $SCIWALL_THEME env var
#   3. ~/.config/linux-setup/theme-state.json  →  "{theme}-{flavor}" (e.g. catppuccin-mocha)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCIWALL_DIR="${SCIWALL_DIR:-$HOME/.local/share/sciwall}"
SCIWALL_REPO="https://github.com/Baroude/Sciwall"
THEME_STATE_FILE="${THEME_STATE_FILE:-$HOME/.config/linux-setup/theme-state.json}"
WALLPAPER_ROOT="${REPO_DIR}/images/wallpaper-rotation"

SCIWALL_THEME="${SCIWALL_THEME:-}"
EXTRA_ARGS=()

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme)    SCIWALL_THEME="$2"; shift 2 ;;
    --theme=*)  SCIWALL_THEME="${1#--theme=}"; shift ;;
    *)          EXTRA_ARGS+=("$1"); shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info() { echo -e "\033[1;34m==>\033[0m $*"; }
ok()   { echo -e "\033[1;32m OK\033[0m $*"; }
warn() { echo -e "\033[1;33mWRN\033[0m $*"; }

# ---------------------------------------------------------------------------
# Resolve theme from state file if not provided
# ---------------------------------------------------------------------------
if [[ -z "$SCIWALL_THEME" && -f "$THEME_STATE_FILE" ]]; then
  SCIWALL_THEME="$(python3 - "$THEME_STATE_FILE" <<'PY'
import json, sys
from pathlib import Path

state = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
theme  = state.get("theme",  "")
flavor = state.get("flavor", "")

# Map to Sciwall naming convention: catppuccin-mocha, tokyo-night, etc.
if theme and flavor:
    print(f"{theme}-{flavor}")
elif theme:
    print(theme)
else:
    print("")
PY
)"
fi

if [[ -z "$SCIWALL_THEME" ]]; then
  echo "ERROR: No theme specified. Use --theme <sciwall-theme> or create theme-state.json." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Clone or update Sciwall
# ---------------------------------------------------------------------------
if [[ -d "$SCIWALL_DIR/.git" ]]; then
  info "Updating Sciwall ($SCIWALL_DIR)..."
  git -C "$SCIWALL_DIR" pull --ff-only 2>/dev/null \
    || warn "Could not pull Sciwall updates — using existing copy"
else
  info "Cloning Sciwall to $SCIWALL_DIR..."
  git clone --depth=1 "$SCIWALL_REPO" "$SCIWALL_DIR"
fi

# ---------------------------------------------------------------------------
# Create venv and install Sciwall
# ---------------------------------------------------------------------------
VENV_DIR="$SCIWALL_DIR/.venv"

if [[ ! -d "$VENV_DIR" ]]; then
  info "Creating Python venv..."
  python3 -m venv "$VENV_DIR"
fi

info "Installing/updating Sciwall in venv..."
"$VENV_DIR/bin/pip" install -q --upgrade pip
"$VENV_DIR/bin/pip" install -q -e "$SCIWALL_DIR"

# ---------------------------------------------------------------------------
# Validate theme availability
# ---------------------------------------------------------------------------
if "$VENV_DIR/bin/generate-wallpapers" --list-themes 2>/dev/null | grep -qiF "$SCIWALL_THEME"; then
  : # theme found
else
  AVAILABLE="$("$VENV_DIR/bin/generate-wallpapers" --list-themes 2>/dev/null || echo "(unavailable)")"
  warn "Theme '$SCIWALL_THEME' not found in Sciwall. Available: $AVAILABLE"
  warn "Proceeding anyway — Sciwall will report an error if the theme is truly missing."
fi

# ---------------------------------------------------------------------------
# Generate wallpapers — one type at a time to prevent OOM from killing
# the entire run (e.g. reaction-diffusion can exhaust VM RAM).
# Falls back to a single invocation if --list-types is not supported.
# ---------------------------------------------------------------------------
# Sciwall creates a <theme>/ subfolder inside --out-dir, so pass WALLPAPER_ROOT
# directly so the final layout is wallpaper-rotation/<theme>/type/file.png.
OUT_DIR="$WALLPAPER_ROOT/$SCIWALL_THEME"
mkdir -p "$WALLPAPER_ROOT"

# If caller already passed --type, honour it directly (single run)
if [[ " ${EXTRA_ARGS[*]-} " == *" --type "* ]]; then
  info "Generating wallpapers (theme: $SCIWALL_THEME → $OUT_DIR)..."
  "$VENV_DIR/bin/generate-wallpapers" \
    --theme "$SCIWALL_THEME" \
    --out-dir "$WALLPAPER_ROOT" \
    --missing-only \
    "${EXTRA_ARGS[@]}"
  ok "Wallpapers ready in: $OUT_DIR"
  exit 0
fi

# Attempt per-type generation for crash/OOM isolation
SCIWALL_TYPES="$("$VENV_DIR/bin/generate-wallpapers" --list-types 2>/dev/null || true)"

if [[ -n "$SCIWALL_TYPES" ]]; then
  info "Generating wallpapers per-type (theme: $SCIWALL_THEME → $OUT_DIR)..."
  _failed_types=()
  while IFS= read -r _type; do
    [[ -z "$_type" ]] && continue
    info "  → $_type"
    if ! "$VENV_DIR/bin/generate-wallpapers" \
        --theme "$SCIWALL_THEME" \
        --out-dir "$WALLPAPER_ROOT" \
        --missing-only \
        --type "$_type" \
        "${EXTRA_ARGS[@]}"; then
      warn "  Type '$_type' failed (OOM?) — skipping"
      _failed_types+=("$_type")
    fi
  done <<< "$SCIWALL_TYPES"
  [[ ${#_failed_types[@]} -gt 0 ]] && warn "Failed types: ${_failed_types[*]}"
else
  # --list-types not supported by this version; run monolithically
  info "Generating wallpapers (theme: $SCIWALL_THEME → $OUT_DIR)..."
  "$VENV_DIR/bin/generate-wallpapers" \
    --theme "$SCIWALL_THEME" \
    --out-dir "$WALLPAPER_ROOT" \
    --missing-only \
    "${EXTRA_ARGS[@]}"
fi

ok "Wallpapers ready in: $OUT_DIR"
