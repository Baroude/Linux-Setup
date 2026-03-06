#!/usr/bin/env bash
# backup-plasma.sh — snapshot KDE Plasma configs to the dotfiles repo
# Run before major KDE upgrades or when you want to commit current state.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLASMA_DIR="$DOTFILES_DIR/plasma"

echo "Backing up Plasma configs to $PLASMA_DIR ..."

cp ~/.config/kwinrc              "$PLASMA_DIR/kwinrc"
cp ~/.config/kdeglobals          "$PLASMA_DIR/kdeglobals"
cp ~/.config/kscreenlockerrc     "$PLASMA_DIR/kscreenlockerrc"

echo "Done. Review changes with: git -C $DOTFILES_DIR diff plasma/"
