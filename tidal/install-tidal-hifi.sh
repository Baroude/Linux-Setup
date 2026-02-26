#!/usr/bin/env bash
# tidal/install-tidal-hifi.sh
# Install tidal-hifi via Flatpak and apply the Catppuccin Mocha CSS theme.
#
# Idempotent: safe to rerun.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_CSS="$SCRIPT_DIR/catppuccin-mocha.css"

APP_ID="com.mastermindzh.tidal-hifi"
CONFIG_DIR="$HOME/.var/app/$APP_ID/config/tidal-hifi"
CONFIG_FILE="$CONFIG_DIR/config.json"

log() {
  printf '\n==> %s\n' "$*"
}

# ---------------------------------------------------------------------------
# Install Flatpak if missing
# ---------------------------------------------------------------------------
install_flatpak() {
  if command -v flatpak &>/dev/null; then
    return
  fi

  log "Installing Flatpak"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y flatpak
  log "Flatpak installed. A reboot may be needed before running apps."
}

ensure_flathub_remote() {
  if ! flatpak remote-list --user | grep -q "^flathub"; then
    log "Adding Flathub remote (user scope)"
    flatpak remote-add --user --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}

# ---------------------------------------------------------------------------
# Install tidal-hifi from Flathub
# ---------------------------------------------------------------------------
install_tidal_hifi() {
  if flatpak list --user --app | grep -q "$APP_ID"; then
    log "tidal-hifi already installed — updating"
    flatpak update --user --noninteractive "$APP_ID" || true
    return
  fi

  log "Installing tidal-hifi from Flathub"
  flatpak install --user --noninteractive flathub "$APP_ID"

  # tidal-hifi 6.0+ runs Electron 39, which dropped ELECTRON_OZONE_PLATFORM_HINT.
  # The run.sh wrapper inside the Flatpak reads XDG_SESSION_TYPE to decide
  # whether to pass --ozone-platform=wayland to Electron. Overriding it to
  # "x11" prevents the Wayland path from being selected.
  # Flatpak 1.16+ (Debian 13) properly scrubs WAYLAND_DISPLAY from the
  # sandbox when --nosocket=wayland is granted, so no manual unset needed.
  # LIBGL_ALWAYS_SOFTWARE=1 is required in VMware VMs where the SVGA driver
  # cannot satisfy Chromium's EGL/DMABuf requirements (VMware: No 3D enabled).
  flatpak override --user \
    --nosocket=wayland \
    --socket=x11 \
    --env=XDG_SESSION_TYPE=x11 \
    --env=LIBGL_ALWAYS_SOFTWARE=1 \
    "$APP_ID"
}

# ---------------------------------------------------------------------------
# Apply Catppuccin Mocha CSS theme via config.json
#
# tidal-hifi stores its config at:
#   ~/.var/app/com.mastermindzh.tidal-hifi/config/tidal-hifi/config.json
#
# The customCSS field is an array of CSS lines.
# We read the theme file, split into lines, and write them into the config.
# If config.json doesn't exist yet we create a minimal valid one.
# ---------------------------------------------------------------------------
apply_theme() {
  if [ ! -f "$THEME_CSS" ]; then
    echo "Theme file not found: $THEME_CSS" >&2
    exit 1
  fi

  log "Applying Catppuccin Mocha theme to tidal-hifi"

  mkdir -p "$CONFIG_DIR"

  # Build a JSON array of CSS lines from the theme file
  local css_lines_json
  css_lines_json="$(awk '{
    # Escape backslashes, then double quotes
    gsub(/\\/, "\\\\")
    gsub(/"/, "\\\"")
    printf "    \"%s\",\n", $0
  }' "$THEME_CSS" | sed '$ s/,$//')"

  if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
    # Merge into existing config preserving all other settings
    python3 - "$CONFIG_FILE" "$THEME_CSS" <<'PYEOF'
import json, sys

config_path = sys.argv[1]
css_path    = sys.argv[2]

with open(config_path, "r") as f:
    config = json.load(f)

with open(css_path, "r") as f:
    css_lines = f.read().splitlines()

config["customCSS"] = css_lines
# "none" skips the theme file lookup; customCSS is applied on top regardless
config["theme"] = "none"

# Disable Wayland and GPU flags — enableWaylandSupport adds
# --ozone-platform-hint=auto which fights our XDG_SESSION_TYPE=x11 override;
# gpuRasterization is pointless without a real GPU (VMware/no-3D).
config.setdefault("flags", {})
config["flags"]["enableWaylandSupport"] = False
config["flags"]["gpuRasterization"] = False

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"  Updated {config_path}")
PYEOF
  else
    # No existing config — write a minimal one
    cat > "$CONFIG_FILE" <<JSONEOF
{
  "theme": "none",
  "customCSS": [
$css_lines_json
  ],
  "flags": {
    "enableWaylandSupport": false,
    "gpuRasterization": false
  }
}
JSONEOF
    log "Created new config: $CONFIG_FILE"
  fi
}

# ---------------------------------------------------------------------------
# Write a local .desktop override that appends --disable-gpu to the Exec
# line. run.sh passes "$@" straight to the Electron binary, so this flag
# reaches Electron and forces software compositing.
# The user file in ~/.local/share/applications/ takes precedence over the
# Flatpak-exported desktop entry and survives flatpak updates.
# ---------------------------------------------------------------------------
write_desktop_override() {
  log "Writing .desktop override with --disable-gpu"
  local desktop_dir="$HOME/.local/share/applications"
  mkdir -p "$desktop_dir"
  cat > "$desktop_dir/$APP_ID.desktop" <<EOF
[Desktop Entry]
Name=TIDAL Hi-Fi
Comment=The web version of listen.tidal.com with Hi-Fi support
Exec=flatpak run $APP_ID --disable-gpu %U
Icon=$APP_ID
Terminal=false
Type=Application
Categories=Audio;Music;Player;Network;
StartupWMClass=tidal-hifi
EOF
  update-desktop-database "$desktop_dir" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  install_flatpak
  ensure_flathub_remote
  install_tidal_hifi
  apply_theme
  write_desktop_override

  log "Done. Launch tidal-hifi with:"
  log "  flatpak run $APP_ID"
  log ""
  log "If the theme isn't applied: open Settings → Theming,"
  log "select 'Custom' from the dropdown, and verify Custom CSS is populated."
  log "To reload CSS without restarting: Ctrl+Shift+R in the app."
}

main "$@"
