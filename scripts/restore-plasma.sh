#!/usr/bin/env bash
# restore-plasma.sh — re-link Plasma configs from the dotfiles repo via dotbot
# Run after a major KDE upgrade once you've verified the configs are compatible.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Re-linking Plasma configs from $DOTFILES_DIR ..."
"$DOTFILES_DIR/install" -c "$DOTFILES_DIR/install-plasma.conf.yaml"
echo "Done. Restart plasmashell: systemctl --user restart plasma-plasmashell"
