#!/usr/bin/env bash
# setup-first-login.sh — One-shot autostart: configure panels + wallpaper
#
# Registered by setup.sh as ~/.config/autostart/kde-post-install.desktop.
# Runs once on first KDE Plasma login, then self-deletes the autostart entry.
#
# Both actions require a live plasmashell session (D-Bus) which is guaranteed
# when run as an autostart application.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Wait for plasmashell to be fully initialised before sending D-Bus calls
sleep 8

# Configure dock (bottom floating pill) and top bar
bash "$REPO_DIR/scripts/configure-dock.sh"

# Apply desktop wallpaper
plasma-apply-wallpaperimage "$REPO_DIR/images/evening-sky.png"

# Self-delete — only needs to run once
rm -f "$HOME/.config/autostart/kde-post-install.desktop"
