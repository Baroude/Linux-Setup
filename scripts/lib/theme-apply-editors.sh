#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme-common.sh"

theme_apply_editors_adapter() {
  local nvim_colors_file="$HOME/.config/nvim/lua/plugins/colorscheme.lua"
  local flavor
  flavor="$(theme_context_get "derived.nvim_flavor")"

  if [[ ! -f "$nvim_colors_file" ]]; then
    theme_warn "Neovim colorscheme file not found at ${nvim_colors_file}; skipping"
    return 0
  fi

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] set Neovim Catppuccin flavour to ${flavor} in ${nvim_colors_file}"
    return 0
  fi

  sed -i -E "s/(flavour\s*=\s*)\"[a-z]+\"/\1\"${flavor}\"/" "$nvim_colors_file"
  theme_info "Editors adapter completed"
}
