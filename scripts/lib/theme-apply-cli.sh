#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme-common.sh"

theme_apply_cli_adapter() {
  local bat_theme btop_theme delta_theme
  local bat_repo bat_file_pattern btop_repo btop_file_pattern
  bat_theme="$(theme_context_get "derived.bat_theme")"
  btop_theme="$(theme_context_get "derived.btop_theme")"
  delta_theme="$(theme_context_get "derived.delta_theme")"
  bat_repo="$(theme_context_get "bat_theme_config.repo")"
  bat_file_pattern="$(theme_context_get "bat_theme_config.resolved_file")"
  btop_repo="$(theme_context_get "btop_theme_config.repo")"
  btop_file_pattern="$(theme_context_get "btop_theme_config.resolved_file")"

  local flavor
  flavor="$(theme_context_get "flavor")"

  local bat_url bat_url_encoded_pattern
  bat_url_encoded_pattern="${bat_file_pattern// /%20}"
  bat_url="${bat_repo}/raw/main/themes/${bat_url_encoded_pattern}"

  theme_run "create bat theme dir" mkdir -p "$HOME/.config/bat/themes"
  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] download bat theme from ${bat_url}"
  else
    curl -fLo "$HOME/.config/bat/themes/${bat_file_pattern}" \
      "${bat_url}"
    if command -v batcat &>/dev/null; then
      batcat cache --build
    elif command -v bat &>/dev/null; then
      bat cache --build
    fi
  fi

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] set bat config theme ${bat_theme}"
  else
    mkdir -p "$HOME/.config/bat"
    if [[ -f "$HOME/.config/bat/config" ]]; then
      if grep -q '^--theme=' "$HOME/.config/bat/config"; then
        sed -i -E "s|^--theme=.*|--theme=\"${bat_theme}\"|" "$HOME/.config/bat/config"
      else
        printf -- '--theme="%s"\n' "$bat_theme" >> "$HOME/.config/bat/config"
      fi
    else
      printf -- '--theme="%s"\n--style=numbers,changes,header\n' "$bat_theme" > "$HOME/.config/bat/config"
    fi
  fi

  local btop_url btop_url_encoded_pattern
  btop_url_encoded_pattern="${btop_file_pattern// /%20}"
  btop_url="${btop_repo}/raw/main/themes/${btop_url_encoded_pattern}"

  theme_run "create btop theme dir" mkdir -p "$HOME/.config/btop/themes"
  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] download btop theme from ${btop_url}"
  else
    curl -fLo "$HOME/.config/btop/themes/${btop_file_pattern}" \
      "${btop_url}"
  fi

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] update btop.conf color_theme=${btop_theme}"
  else
    mkdir -p "$HOME/.config/btop"
    if [[ -f "$HOME/.config/btop/btop.conf" ]]; then
      if grep -q '^color_theme\s*=\s*' "$HOME/.config/btop/btop.conf"; then
        sed -i -E "s|^color_theme\s*=.*|color_theme = \"${btop_theme}\"|" "$HOME/.config/btop/btop.conf"
      else
        printf 'color_theme = "%s"\n' "$btop_theme" >> "$HOME/.config/btop/btop.conf"
      fi
    else
      printf 'color_theme = "%s"\ntheme_background = False\n' "$btop_theme" > "$HOME/.config/btop/btop.conf"
    fi
  fi

  theme_run "set git delta syntax theme" git config --global delta.syntax-theme "$delta_theme"

  theme_run "create fzf config dir" mkdir -p "$HOME/.config/fzf"
  theme_render_template "${THEME_REPO_DIR}/themes/templates/fzf-colors.zsh.tpl" "$HOME/.config/fzf/colors.zsh"

  theme_info "CLI adapter completed (${flavor})"
}
