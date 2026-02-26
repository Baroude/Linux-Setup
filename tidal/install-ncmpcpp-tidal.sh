#!/usr/bin/env bash
# tidal/install-ncmpcpp-tidal.sh
# Install mopidy + mopidy-tidal + ncmpcpp for a terminal Tidal client.
#
# Stack: mopidy (GStreamer / MPD protocol) ← ncmpcpp TUI
# Auth:  Tidal PKCE OAuth (required for LOSSLESS quality)
#
# Idempotent: safe to rerun.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MOPIDY_CONF="$HOME/.config/mopidy/mopidy.conf"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
NCMPCPP_DIR="$HOME/.config/ncmpcpp"

log() {
  printf '\n==> %s\n' "$*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Detect Debian/Ubuntu codename
# ---------------------------------------------------------------------------
detect_codename() {
  if command_exists lsb_release; then
    lsb_release -cs
  elif [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s' "${VERSION_CODENAME:-unknown}"
  else
    printf 'unknown'
  fi
}

# ---------------------------------------------------------------------------
# Install mopidy
#
# mopidy publishes signed apt packages for bullseye and bookworm.
# For anything else we fall back to pip.
# ---------------------------------------------------------------------------
install_mopidy() {
  if command_exists mopidy; then
    log "mopidy already installed — skipping"
    return
  fi

  local codename
  codename="$(detect_codename)"

  case "$codename" in
    bullseye|bookworm|focal|jammy|noble)
      log "Adding mopidy apt repository ($codename)"
      curl -fsSL https://apt.mopidy.com/mopidy.gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/mopidy-archive-keyring.gpg
      echo "deb [signed-by=/usr/share/keyrings/mopidy-archive-keyring.gpg] \
https://apt.mopidy.com/ $codename main contrib non-free" \
        | sudo tee /etc/apt/sources.list.d/mopidy.list > /dev/null
      sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mopidy
      ;;
    *)
      log "Codename '$codename' not in mopidy apt repo — installing via pip"
      sudo pip3 install --break-system-packages Mopidy
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Install GStreamer plugins (audio decoding / output)
# ---------------------------------------------------------------------------
install_gstreamer() {
  log "Installing GStreamer plugins"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-tools \
    gstreamer1.0-alsa \
    gstreamer1.0-pulseaudio 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Install mopidy-tidal (EbbLabs fork, supports PKCE + lossless)
#
# Must land in the same Python environment as mopidy.
# ---------------------------------------------------------------------------
install_mopidy_tidal() {
  if python3 -c "import mopidy_tidal" 2>/dev/null; then
    log "mopidy-tidal already installed — updating"
    sudo pip3 install --break-system-packages --upgrade Mopidy-Tidal 2>/dev/null \
      || pip3 install --user --upgrade Mopidy-Tidal
    return
  fi

  log "Installing mopidy-tidal"
  sudo pip3 install --break-system-packages Mopidy-Tidal 2>/dev/null \
    || pip3 install --user Mopidy-Tidal
}

# ---------------------------------------------------------------------------
# Install ncmpcpp
# ---------------------------------------------------------------------------
install_ncmpcpp() {
  if command_exists ncmpcpp; then
    log "ncmpcpp already installed"
    return
  fi

  log "Installing ncmpcpp"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ncmpcpp
}

# ---------------------------------------------------------------------------
# Disable the system mopidy service to avoid port 6600 conflicts
# ---------------------------------------------------------------------------
disable_system_mopidy() {
  if systemctl is-enabled --quiet mopidy 2>/dev/null; then
    log "Disabling system mopidy service (conflicts with user service)"
    sudo systemctl disable --now mopidy 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Write mopidy user config (skip if already present — may contain auth tokens)
# ---------------------------------------------------------------------------
install_mopidy_config() {
  if [ -f "$MOPIDY_CONF" ]; then
    log "mopidy config already exists — skipping (delete $MOPIDY_CONF to reset)"
    return
  fi

  log "Installing mopidy config: $MOPIDY_CONF"
  mkdir -p "$(dirname "$MOPIDY_CONF")"
  cp "$SCRIPT_DIR/mopidy.conf" "$MOPIDY_CONF"
}

# ---------------------------------------------------------------------------
# Install user systemd service, patching ExecStart to the real mopidy path
# ---------------------------------------------------------------------------
install_systemd_service() {
  log "Installing mopidy user systemd service"
  mkdir -p "$SYSTEMD_USER_DIR"

  local mopidy_bin
  mopidy_bin="$(command -v mopidy 2>/dev/null || echo '/usr/bin/mopidy')"

  sed "s|/usr/bin/mopidy|${mopidy_bin}|g" \
    "$SCRIPT_DIR/mopidy.service" \
    > "$SYSTEMD_USER_DIR/mopidy.service"

  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user enable mopidy 2>/dev/null || true

  # Allow the service to run after logout (headless / server setups)
  loginctl enable-linger "$USER" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Install ncmpcpp config (skip if already present)
# ---------------------------------------------------------------------------
install_ncmpcpp_config() {
  mkdir -p "$NCMPCPP_DIR"

  if [ ! -f "$NCMPCPP_DIR/config" ]; then
    log "Installing ncmpcpp config"
    cp "$SCRIPT_DIR/ncmpcpp/config" "$NCMPCPP_DIR/config"
  else
    log "ncmpcpp config already exists — skipping"
  fi

  if [ ! -f "$NCMPCPP_DIR/bindings" ]; then
    log "Installing ncmpcpp bindings"
    cp "$SCRIPT_DIR/ncmpcpp/bindings" "$NCMPCPP_DIR/bindings"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  install_mopidy
  install_gstreamer
  install_mopidy_tidal
  install_ncmpcpp
  disable_system_mopidy
  install_mopidy_config
  install_systemd_service
  install_ncmpcpp_config

  log "Done."
  log ""
  log "First-time Tidal authentication (PKCE):"
  log ""
  log "  1. Run mopidy in the foreground (NOT via journalctl — it needs input):"
  log "       systemctl --user stop mopidy 2>/dev/null; mopidy"
  log ""
  log "  2. Watch for a URL starting with https://login.tidal.com/..."
  log "     Open it in a browser and log in to Tidal."
  log ""
  log "  3. After login Tidal redirects to http://localhost:8989/..."
  log "     Copy the full redirect URL from your browser address bar."
  log "     Paste it into the terminal running mopidy and press Enter."
  log ""
  log "  4. The token is saved to ~/.local/share/mopidy/mopidy-tidal/"
  log "     Subsequent starts pick it up automatically."
  log ""
  log "  5. Stop the foreground run (Ctrl-C), then start the service:"
  log "       systemctl --user start mopidy"
  log ""
  log "  6. Open the TUI:"
  log "       ncmpcpp"
  log ""
  log "Useful ncmpcpp keys (see bindings for full list):"
  log "  2 / 4  browser / media library   3  search"
  log "  Enter  play    a  add to queue   space  pause"
  log "  j/k    up/down  g/G  home/end    h/l  parent/enter dir"
}

main "$@"
