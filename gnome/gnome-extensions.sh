#!/usr/bin/env bash
# gnome/gnome-extensions.sh
# Install, enable, and configure GNOME Shell extensions.
#
# Requires:
#   - A running GNOME session (DISPLAY or WAYLAND_DISPLAY set)
#   - gnome-extensions-cli (gext) installed via pip
#   - dconf-cli (apt package: dconf-cli)
#
# Idempotent: safe to rerun.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DCONF_DIR="$SCRIPT_DIR/dconf"

log() {
  printf '\n==> %s\n' "$*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Guard: must be in a live GNOME session
# ---------------------------------------------------------------------------
check_gnome_session() {
  if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    echo "No DISPLAY or WAYLAND_DISPLAY found. Run this inside a GNOME session." >&2
    exit 1
  fi
  if ! command_exists gnome-shell; then
    echo "gnome-shell not found. Is GNOME installed?" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Install gext (gnome-extensions-cli)
# ---------------------------------------------------------------------------
install_gext() {
  if command_exists gext; then
    return
  fi
  log "Installing gnome-extensions-cli (gext)"
  pipx install gnome-extensions-cli
  # Ensure ~/.local/bin is on PATH for this session
  export PATH="$HOME/.local/bin:$PATH"
}

# ---------------------------------------------------------------------------
# Install dconf-cli if missing
# ---------------------------------------------------------------------------
install_dconf_cli() {
  if command_exists dconf; then
    return
  fi
  log "Installing dconf-cli"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y dconf-cli
}

# ---------------------------------------------------------------------------
# Install and enable a single extension by its extensions.gnome.org numeric ID
# Usage: install_extension <numeric-id> <uuid>
# ---------------------------------------------------------------------------
install_extension() {
  local id="$1"
  local uuid="$2"

  if gext list | grep -qxF "$uuid"; then
    log "Extension already installed: $uuid"
    gext enable "$uuid" 2>/dev/null || true
  else
    log "Installing extension: $uuid (ID: $id)"
    gext install "$id"
  fi
}

# ---------------------------------------------------------------------------
# Load dconf settings from a keyfile fragment
# Usage: load_dconf <path-in-dconf-dir>
# The file must be a dconf keyfile with a [/org/gnome/...] section header.
# ---------------------------------------------------------------------------
load_dconf() {
  local conf_file="$DCONF_DIR/$1"
  if [ ! -f "$conf_file" ]; then
    echo "dconf config not found: $conf_file" >&2
    return 1
  fi
  log "Loading dconf settings from $1"
  dconf load / < "$conf_file"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  check_gnome_session
  install_dconf_cli
  install_gext

  log "Installing GNOME Shell extensions"

  # Open Bar — top bar styling (panel background, blur, colors, rounded corners)
  install_extension 6580 "openbar@neuromorph"

  # Blur my Shell — blur panel, overview, app-launcher backgrounds
  install_extension 3193 "blur-my-shell@aunetx"

  # Dash to Dock — dock auto-hide, position, icon size
  install_extension 307  "dash-to-dock@micxgx.gmail.com"

  # Tiling Shell — full tiling WM (snap zones, keyboard-driven layouts)
  install_extension 7065 "tilingshell@ferrarodomenico.com"

  log "Applying extension dconf settings"
  load_dconf "extensions.conf"

  log "GNOME extensions setup complete."
  log "You may need to log out and back in for all changes to take effect."
}

main "$@"
