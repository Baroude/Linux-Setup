#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme-common.sh"

theme_apply_terminal_adapter() {
  local kitty_conf="$HOME/.config/kitty/kitty.conf"
  local kitty_theme="$HOME/.config/kitty/theme.conf"
  local starship_out="$HOME/.config/starship.toml"

  theme_run "create kitty config dir" mkdir -p "$HOME/.config/kitty"

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] ensure kitty include ./theme.conf in ${kitty_conf}"
  else
    if [[ -f "$kitty_conf" ]]; then
      if ! grep -Eq '^[[:space:]]*include[[:space:]]+\./theme\.conf([[:space:]]*#.*)?$' "$kitty_conf"; then
        printf '\ninclude ./theme.conf\n' >> "$kitty_conf"
      fi
    else
      printf 'include ./theme.conf\n' > "$kitty_conf"
    fi
  fi

  theme_render_template "${THEME_REPO_DIR}/themes/templates/kitty-theme.conf.tpl" "$kitty_theme"
  theme_render_template "${THEME_REPO_DIR}/themes/templates/starship.toml.tpl" "$starship_out"

  theme_info "Terminal adapter completed"
}
