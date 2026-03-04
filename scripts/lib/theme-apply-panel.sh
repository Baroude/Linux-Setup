#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme-common.sh"

THEME_PANEL_PRESET_FILE="${HOME}/.config/linux-setup/panel-colorizer-global.json"
THEME_PANEL_WIDGET_COLORS_JSON="{}"

_theme_panel_dbus_cmd() {
  if command -v qdbus6 &>/dev/null; then
    echo "qdbus6"
  else
    echo "qdbus"
  fi
}

theme_panel_prepare_assets() {
  theme_render_template "${THEME_REPO_DIR}/themes/templates/panel-colorizer-global.json.tpl" "$THEME_PANEL_PRESET_FILE"
  THEME_PANEL_WIDGET_COLORS_JSON="$(theme_context_get "widget_colors")"
  export THEME_PANEL_PRESET_FILE THEME_PANEL_WIDGET_COLORS_JSON
}

theme_panel_detect_ids() {
  local dbus_cmd
  dbus_cmd="$(_theme_panel_dbus_cmd)"

  local top_id
  top_id=$($dbus_cmd org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var t=panelIds.filter(function(id){return panelById(id)&&panelById(id).location==='top';}); print(t[t.length-1]);" \
    2>/dev/null | tail -1)
  [[ "${top_id:-}" =~ ^[0-9]+$ ]] || return 1

  local pc_id
  pc_id=$($dbus_cmd org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var p=panelById(${top_id}); var ws=p.widgets(['luisbocanegra.panel.colorizer']); print(ws.length>0?ws[0].id:'NOT_FOUND');" \
    2>/dev/null | tail -1)
  [[ "${pc_id:-}" =~ ^[0-9]+$ ]] || return 1

  local spacer_ids_json top_widgets_json
  spacer_ids_json=$($dbus_cmd org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var p=panelById(${top_id}); var ws=p.widgets(['org.kde.plasma.panelspacer']); var ids=[]; ws.forEach(function(w){ids.push(w.id);}); print(JSON.stringify(ids));" \
    2>/dev/null | tail -1)

  top_widgets_json=$($dbus_cmd org.kde.plasmashell /PlasmaShell \
    org.kde.PlasmaShell.evaluateScript \
    "var p=panelById(${top_id}); var ws=p.widgets(); var out=[]; ws.forEach(function(w){out.push({id:w.id,name:w.type});}); print(JSON.stringify(out));" \
    2>/dev/null | tail -1)

  echo "$top_id"
  echo "$pc_id"
  echo "${spacer_ids_json:-[]}"
  echo "${top_widgets_json:-[]}"
}

theme_panel_apply_live() {
  local write_disk="$1"

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] panel colorizer apply (write_disk=${write_disk})"
    return 0
  fi

  local dbus_cmd
  dbus_cmd="$(_theme_panel_dbus_cmd)"

  local detected
  if ! detected="$(theme_panel_detect_ids)"; then
    theme_warn "Panel Colorizer not ready yet; skipping live apply"
    return 1
  fi

  local top_id pc_id spacer_ids_json top_widgets_json
  top_id="$(echo "$detected" | sed -n '1p')"
  pc_id="$(echo "$detected" | sed -n '2p')"
  spacer_ids_json="$(echo "$detected" | sed -n '3p')"
  top_widgets_json="$(echo "$detected" | sed -n '4p')"

  PANEL_PRESET_FILE="$THEME_PANEL_PRESET_FILE" \
  PANEL_WIDGET_COLORS_JSON="$THEME_PANEL_WIDGET_COLORS_JSON" \
  PANEL_ID="$top_id" \
  APPLET_ID="$pc_id" \
  SPACER_IDS_JSON="$spacer_ids_json" \
  TOP_WIDGETS_JSON="$top_widgets_json" \
  PANEL_WRITE_DISK="$write_disk" \
  DBUS_CMD="$dbus_cmd" \
  python3 "${THEME_REPO_DIR}/scripts/lib/panel-colorizer-apply.py"
}

theme_apply_panel_adapter() {
  theme_panel_prepare_assets
  if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    theme_warn "No active desktop session detected; panel apply deferred"
    return 0
  fi
  theme_panel_apply_live 0
}
