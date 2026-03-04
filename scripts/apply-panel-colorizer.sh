#!/usr/bin/env bash
# apply-panel-colorizer.sh
# KDE autostart - reapplies Panel Colorizer from active theme state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/theme-common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/theme-apply-panel.sh"

resolve_selection() {
  local defaults_json default_theme default_flavor default_accent
  defaults_json="$(theme_defaults_json)"
  default_theme="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["theme"])' <<<"$defaults_json")"
  default_flavor="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["flavor"])' <<<"$defaults_json")"
  default_accent="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["accent"])' <<<"$defaults_json")"

  local state_theme="" state_flavor="" state_accent=""
  if readarray -t state_triplet < <(theme_read_state_selection 2>/dev/null); then
    state_theme="${state_triplet[0]:-}"
    state_flavor="${state_triplet[1]:-}"
    state_accent="${state_triplet[2]:-}"
  fi

  local selected_theme selected_flavor selected_accent
  selected_theme="${state_theme:-$default_theme}"
  selected_flavor="${state_flavor:-$default_flavor}"
  selected_accent="${state_accent:-$default_accent}"

  if ! theme_validate_selection "$selected_theme" "$selected_flavor" "$selected_accent"; then
    selected_theme="$default_theme"
    selected_flavor="$default_flavor"
    selected_accent="$default_accent"
  fi

  echo "$selected_theme"
  echo "$selected_flavor"
  echo "$selected_accent"
}

mapfile -t selection < <(resolve_selection)
THEME_CONTEXT_JSON="$(theme_build_context_json "${selection[0]}" "${selection[1]}" "${selection[2]}")"
export THEME_CONTEXT_JSON

theme_panel_prepare_assets

DBUS_CMD="qdbus6"
command -v qdbus6 &>/dev/null || DBUS_CMD="qdbus"

for _ in $(seq 1 30); do
  if $DBUS_CMD org.kde.plasmashell /PlasmaShell \
      org.kde.PlasmaShell.evaluateScript "print('ok');" 2>/dev/null | grep -q 'ok'; then
    break
  fi
  sleep 1
done
sleep 4

theme_panel_apply_live 0
