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
# Point the theme selector to "Custom" so tidal-hifi uses our CSS
config["theme"] = "Custom"

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"  Updated {config_path}")
PYEOF
  else
    # No existing config — write a minimal one
    cat > "$CONFIG_FILE" <<JSONEOF
{
  "theme": "Custom",
  "customCSS": [
$css_lines_json
  ],
  "settings": {}
}
JSONEOF
    log "Created new config: $CONFIG_FILE"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  install_flatpak
  ensure_flathub_remote
  install_tidal_hifi
  apply_theme

  log "Done. Launch tidal-hifi with:"
  log "  flatpak run $APP_ID"
  log ""
  log "If the theme isn't applied: open Settings → Theming,"
  log "select 'Custom' from the dropdown, and verify Custom CSS is populated."
  log "To reload CSS without restarting: Ctrl+Shift+R in the app."
}

main "$@"
