#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme-common.sh"

# Validate a single path component (no traversal, no metacharacters, non-empty).
_grub_validate_path_component() {
  local value="$1" label="$2"
  if [[ -z "$value" ]]; then
    theme_err "${label} is empty; aborting"
    return 1
  fi
  if [[ "$value" == *".."* || "$value" == "/"* || "$value" =~ [[:space:]\;\&\|\`\$\(\)\<\>\!\*\?] ]]; then
    theme_err "Unsafe ${label} '${value}': contains path traversal or shell metacharacters; aborting"
    return 1
  fi
}

# Substitute ${flavor} and ${accent} tokens in a pattern string.
_grub_sub() {
  local pattern="$1"
  local flavor accent
  flavor="$(theme_context_get "flavor")"
  accent="$(theme_context_get "accent")"
  printf '%s' "$pattern" | sed "s/\${flavor}/$flavor/g; s/\${accent}/$accent/g"
}

# Post-install: set GRUB_THEME + GRUB_GFXMODE in /etc/default/grub, then update-grub.
_grub_post_install() {
  local target_name="$1"
  local theme_txt="/usr/share/grub/themes/${target_name}/theme.txt"
  local grub_file="/etc/default/grub"

  if grep -q "^#\?GRUB_THEME=" "$grub_file"; then
    theme_run "set GRUB_THEME" \
      sudo sed -i "s|^#\?GRUB_THEME=.*|GRUB_THEME=\"${theme_txt}\"|" "$grub_file"
  else
    theme_run_shell "set GRUB_THEME" \
      "echo 'GRUB_THEME=\"${theme_txt}\"' | sudo tee -a '${grub_file}' > /dev/null"
  fi
  if grep -q "^#\?GRUB_GFXMODE=" "$grub_file"; then
    theme_run "set GRUB_GFXMODE" \
      sudo sed -i 's|^#\?GRUB_GFXMODE=.*|GRUB_GFXMODE=1920x1080|' "$grub_file"
  else
    theme_run_shell "set GRUB_GFXMODE" \
      "echo 'GRUB_GFXMODE=1920x1080' | sudo tee -a '${grub_file}' > /dev/null"
  fi
  theme_run "update-grub" sudo update-grub
}

theme_apply_grub_adapter() {
  local method target_name
  method="$(theme_context_get "grub_config.method")"

  if [[ -z "$method" ]]; then
    theme_err "grub_config.method is empty — is grub_config defined in the manifest?"
    return 1
  fi

  theme_info "Applying GRUB theme (method: ${method})"

  case "$method" in
    catppuccin_git)
      local repo theme_subdir_pattern target_name_pattern theme_subdir
      repo="$(theme_context_get "grub_config.repo")"
      theme_subdir_pattern="$(theme_context_get "grub_config.theme_subdir_pattern")"
      target_name_pattern="$(theme_context_get "grub_config.target_name_pattern")"
      theme_subdir="$(_grub_sub "$theme_subdir_pattern")"
      target_name="$(_grub_sub "$target_name_pattern")"

      _grub_validate_path_component "$target_name" "target_name" || return 1
      _grub_validate_path_component "$theme_subdir" "theme_subdir" || return 1

      theme_clone_fresh /tmp/theme-grub "$repo"
      theme_run "ensure grub themes dir" sudo mkdir -p /usr/share/grub/themes
      theme_run "remove old grub theme" sudo rm -rf "/usr/share/grub/themes/${target_name}"
      theme_run "install grub theme" \
        sudo cp -r "/tmp/theme-grub/${theme_subdir}" "/usr/share/grub/themes/${target_name}"
      [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/theme-grub
      ;;

    git_grub)
      local repo theme_subdir
      repo="$(theme_context_get "grub_config.repo")"
      theme_subdir="$(theme_context_get "grub_config.theme_subdir")"
      target_name="$(theme_context_get "grub_config.target_name")"

      _grub_validate_path_component "$target_name" "target_name" || return 1
      [[ "$theme_subdir" != "." ]] && _grub_validate_path_component "$theme_subdir" "theme_subdir"

      theme_clone_fresh /tmp/theme-grub "$repo"
      theme_run "ensure grub themes dir" sudo mkdir -p /usr/share/grub/themes
      theme_run "remove old grub theme" sudo rm -rf "/usr/share/grub/themes/${target_name}"
      if [[ "$theme_subdir" == "." ]]; then
        theme_run "install grub theme" \
          sudo cp -r /tmp/theme-grub "/usr/share/grub/themes/${target_name}"
      else
        theme_run "install grub theme" \
          sudo cp -r "/tmp/theme-grub/${theme_subdir}" "/usr/share/grub/themes/${target_name}"
      fi
      [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/theme-grub
      ;;

    *)
      theme_err "Unknown grub method: ${method}"
      return 1
      ;;
  esac

  _grub_post_install "$target_name"
  theme_info "GRUB adapter completed"
}
