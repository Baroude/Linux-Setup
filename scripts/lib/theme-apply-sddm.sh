#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme-common.sh"

# Substitute ${flavor} and ${accent} tokens in a pattern string.
_sddm_sub() {
  local pattern="$1"
  local flavor accent
  flavor="$(theme_context_get "flavor")"
  accent="$(theme_context_get "accent")"
  printf '%s' "$pattern" | sed "s/\${flavor}/$flavor/g; s/\${accent}/$accent/g"
}

# Write /etc/sddm.conf.d/10-theme.conf to activate the given theme.
_sddm_activate() {
  local target_name="$1"
  theme_run "create sddm conf.d dir" sudo mkdir -p /etc/sddm.conf.d
  theme_run_shell "activate sddm theme" \
    "printf '[Theme]\nCurrent=${target_name}\n' | sudo tee /etc/sddm.conf.d/10-theme.conf > /dev/null"
}

# Post-install: write sddm.conf.d activation file and optional wallpaper (for simple themes).
_sddm_post_install() {
  local target_name="$1"
  local install_dir="/usr/share/sddm/themes/${target_name}"

  _sddm_activate "$target_name"

  local bg_src="${THEME_REPO_DIR}/images/evening-sky.png"
  if [[ -f "$bg_src" ]]; then
    # Detect existing backgrounds dir casing (themes vary: Backgrounds/ vs backgrounds/)
    local bg_dir="backgrounds"
    [[ -d "${install_dir}/Backgrounds" ]] && bg_dir="Backgrounds"
    theme_run "create sddm backgrounds dir" sudo mkdir -p "${install_dir}/${bg_dir}"
    theme_run "copy sddm background" sudo cp "$bg_src" "${install_dir}/${bg_dir}/evening-sky.png"
    theme_run_shell "write sddm theme.conf.user" \
      "printf '[General]\nBackground=${bg_dir}/evening-sky.png\n' | sudo tee '${install_dir}/theme.conf.user' > /dev/null"
  fi
}

# Write a full theme.conf.user for where_is_my_sddm_theme using Catppuccin palette tokens.
_sddm_write_where_is_my_conf() {
  local target_name="$1"
  local install_dir="/usr/share/sddm/themes/${target_name}"

  local base text accent surface0 red
  base="$(theme_context_get "tokens.BASE")"
  text="$(theme_context_get "tokens.TEXT")"
  accent="$(theme_context_get "tokens.ACCENT")"
  surface0="$(theme_context_get "tokens.SURFACE0")"
  red="$(theme_context_get "tokens.RED")"

  local font blur_radius input_radius input_border_width wrong_border_radius show_user show_user_real_name
  font="$(theme_context_get "sddm_config.font")"
  blur_radius="$(theme_context_get "sddm_config.blur_radius")"
  input_radius="$(theme_context_get "sddm_config.password_input_radius")"
  input_border_width="$(theme_context_get "sddm_config.password_input_border_width")"
  wrong_border_radius="$(theme_context_get "sddm_config.wrong_password_border_radius")"
  show_user="$(theme_context_get "sddm_config.show_user")"
  show_user_real_name="$(theme_context_get "sddm_config.show_user_real_name")"

  local bg_image_key
  bg_image_key="$(theme_context_get "sddm_config.background_image")"
  local bg_src="${THEME_REPO_DIR}/images/evening-sky.png"
  [[ -n "$bg_image_key" ]] && bg_src="${THEME_REPO_DIR}/${bg_image_key}"
  local bg_line=""
  if [[ -f "$bg_src" ]]; then
    local bg_filename
    bg_filename="$(basename "$bg_src")"
    theme_run "create sddm backgrounds dir" sudo mkdir -p "${install_dir}/backgrounds"
    theme_run "copy sddm background" sudo cp "$bg_src" "${install_dir}/backgrounds/${bg_filename}"
    bg_line="background=backgrounds/${bg_filename}"
  fi

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] write sddm theme.conf.user (base=${base} text=${text} accent=${accent})"
    return 0
  fi

  local tmp_conf
  tmp_conf="$(mktemp)"
  {
    echo "[General]"
    echo "backgroundFill=${base}"
    echo "basicTextColor=${text}"
    echo "passwordCursorColor=${accent}"
    echo "passwordInputBackground=${surface0}"
    echo "passwordTextColor=${text}"
    echo "wrongPasswordBorderColor=${red}"
    echo "passwordInputBorderColor=${accent}"
    echo "font=${font}"
    echo "blurRadius=${blur_radius}"
    echo "passwordInputRadius=${input_radius}"
    echo "passwordInputBorderWidth=${input_border_width}"
    echo "wrongPasswordBorderRadius=${wrong_border_radius}"
    [[ -n "$show_user" ]] && echo "showUsersByDefault=${show_user}"
    [[ -n "$show_user_real_name" ]] && echo "showUserRealNameByDefault=${show_user_real_name}"
    [[ -n "$bg_line" ]] && echo "$bg_line"
  } > "$tmp_conf"
  sudo cp "$tmp_conf" "${install_dir}/theme.conf.user"
  rm -f "$tmp_conf"
}

theme_apply_sddm_adapter() {
  local method target_name
  method="$(theme_context_get "sddm_config.method")"

  if [[ -z "$method" ]]; then
    theme_err "sddm_config.method is empty — is sddm_config defined in the manifest?"
    return 1
  fi

  theme_info "Applying SDDM theme (method: ${method})"

  case "$method" in
    catppuccin_release)
      local repo zip_pattern target_name_pattern zip_name url
      repo="$(theme_context_get "sddm_config.repo")"
      zip_pattern="$(theme_context_get "sddm_config.zip_pattern")"
      target_name_pattern="$(theme_context_get "sddm_config.target_name_pattern")"
      zip_name="$(_sddm_sub "$zip_pattern")"
      target_name="$(_sddm_sub "$target_name_pattern")"
      url="https://github.com/${repo}/releases/latest/download/${zip_name}"

      theme_run "remove old sddm theme" sudo rm -rf "/usr/share/sddm/themes/${target_name}"
      if [[ "${THEME_DRY_RUN}" == "1" ]]; then
        echo "[dry-run] download ${url}"
        echo "[dry-run] unzip ${zip_name} and sudo mv to /usr/share/sddm/themes/${target_name}"
      else
        local tmp_dir
        tmp_dir="$(mktemp -d)"
        curl -LOsS -o "${tmp_dir}/${zip_name}" "$url"
        unzip -o "${tmp_dir}/${zip_name}" -d "$tmp_dir"
        sudo mv "${tmp_dir}/${target_name}" /usr/share/sddm/themes/
        rm -rf "$tmp_dir"
      fi
      _sddm_post_install "$target_name"
      ;;

    git_sddm)
      local repo theme_subdir
      repo="$(theme_context_get "sddm_config.repo")"
      theme_subdir="$(theme_context_get "sddm_config.theme_subdir")"
      target_name="$(theme_context_get "sddm_config.target_name")"

      theme_clone_fresh /tmp/theme-sddm "$repo"
      theme_run "remove old sddm theme" sudo rm -rf "/usr/share/sddm/themes/${target_name}"
      if [[ "$theme_subdir" == "." ]]; then
        theme_run "install sddm theme" sudo cp -r /tmp/theme-sddm "/usr/share/sddm/themes/${target_name}"
      else
        theme_run "install sddm theme" sudo cp -r "/tmp/theme-sddm/${theme_subdir}" "/usr/share/sddm/themes/${target_name}"
      fi
      [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/theme-sddm
      _sddm_post_install "$target_name"
      ;;

    where_is_my_sddm)
      local upstream_repo upstream_subdir
      upstream_repo="$(theme_context_get "sddm_config.upstream_repo")"
      upstream_subdir="$(theme_context_get "sddm_config.upstream_subdir")"
      target_name="$(theme_context_get "sddm_config.target_name")"

      theme_clone_fresh /tmp/theme-sddm "$upstream_repo"
      theme_run "remove old sddm theme" sudo rm -rf "/usr/share/sddm/themes/${target_name}"
      if [[ "$upstream_subdir" == "." ]]; then
        theme_run "install sddm theme" sudo cp -r /tmp/theme-sddm "/usr/share/sddm/themes/${target_name}"
      else
        theme_run "install sddm theme" sudo cp -r "/tmp/theme-sddm/${upstream_subdir}" "/usr/share/sddm/themes/${target_name}"
      fi
      [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/theme-sddm

      _sddm_activate "$target_name"
      _sddm_write_where_is_my_conf "$target_name"
      ;;

    *)
      theme_err "Unknown sddm method: ${method}"
      return 1
      ;;
  esac

  theme_info "SDDM adapter completed"
}
