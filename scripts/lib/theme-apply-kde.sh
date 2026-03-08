#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme-common.sh"

# ---------------------------------------------------------------------------
# KDE Plasma install — dispatches on kde_install_config.method
# ---------------------------------------------------------------------------

_kde_install_plasma() {
  local kde_method kde_repo lookandfeel
  kde_method="$(theme_context_get "kde_install_config.method")"
  kde_repo="$(theme_context_get "kde_install_config.repo")"
  lookandfeel="$(theme_context_get "derived.kde_lookandfeel")"

  case "$kde_method" in
    catppuccin_script)
      local flavor_idx accent_idx flavor accent
      flavor="$(theme_context_get "flavor")"
      accent="$(theme_context_get "accent")"
      flavor_idx="$(theme_context_get "kde_installer_index.flavor.${flavor}")"
      accent_idx="$(theme_context_get "kde_installer_index.accent.${accent}")"
      theme_clone_fresh /tmp/theme-kde "$kde_repo"
      if [[ "${THEME_DRY_RUN}" == "1" ]]; then
        echo "[dry-run] run catppuccin/kde install.sh ${flavor_idx} ${accent_idx} 1"
      else
        (
          cd /tmp/theme-kde
          printf 'y\ny\n' | ./install.sh "$flavor_idx" "$accent_idx" 1
        )
      fi
      [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/theme-kde
      ;;

    lookandfeel)
      theme_clone_fresh /tmp/theme-kde "$kde_repo"
      if [[ "${THEME_DRY_RUN}" == "1" ]]; then
        echo "[dry-run] kpackagetool6 --type Plasma/LookAndFeel --install <packages>"
        echo "[dry-run] plasma-apply-lookandfeel --apply ${lookandfeel}"
      else
        # Install every top-level package directory then apply the selected one
        for pkg_dir in /tmp/theme-kde/*/; do
          [[ -f "${pkg_dir}metadata.json" || -f "${pkg_dir}metadata.desktop" ]] || continue
          kpackagetool6 --type Plasma/LookAndFeel --install "$pkg_dir" 2>/dev/null || true
        done
        rm -rf /tmp/theme-kde
        plasma-apply-lookandfeel --apply "$lookandfeel"
      fi
      ;;

    plasma_package)
      theme_clone_fresh /tmp/theme-kde "$kde_repo"
      if [[ "${THEME_DRY_RUN}" == "1" ]]; then
        echo "[dry-run] kpackagetool6 --install /tmp/theme-kde"
        echo "[dry-run] plasma-apply-lookandfeel --apply ${lookandfeel}"
      else
        kpackagetool6 --install /tmp/theme-kde
        rm -rf /tmp/theme-kde
        plasma-apply-lookandfeel --apply "$lookandfeel"
      fi
      ;;

    "")
      theme_warn "kde_install_config.method is empty; skipping plasma install"
      ;;

    *)
      theme_warn "Unknown kde install method '${kde_method}'; skipping"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Kvantum install — dispatches on kvantum_config.method
# ---------------------------------------------------------------------------

_kde_install_kvantum() {
  local kvantum_enabled
  kvantum_enabled="$(theme_context_get "kvantum_config.enabled")"

  if [[ "$kvantum_enabled" != "true" ]]; then
    theme_info "Kvantum disabled for this theme; skipping"
    return 0
  fi

  local kvantum_method kvantum_theme
  kvantum_method="$(theme_context_get "kvantum_config.method")"
  # kvantum_theme is read here as default; tarball_release overrides it below
  kvantum_theme="$(theme_context_get "derived.kvantum_theme" 2>/dev/null)" || kvantum_theme=""

  case "$kvantum_method" in
    catppuccin_repo)
      local kvantum_repo
      kvantum_repo="$(theme_context_get "kvantum_config.repo")"
      theme_clone_fresh /tmp/theme-kvantum "$kvantum_repo"
      theme_run "create kvantum dir" mkdir -p "$HOME/.config/Kvantum"
      theme_run "remove previous kvantum theme dir" rm -rf "$HOME/.config/Kvantum/${kvantum_theme}"
      theme_run "install kvantum theme files" cp -r "/tmp/theme-kvantum/themes/${kvantum_theme}" "$HOME/.config/Kvantum/"
      [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/theme-kvantum
      ;;

    kvantum_repo)
      local kvantum_repo
      kvantum_repo="$(theme_context_get "kvantum_config.repo")"
      # Generic: clone repo, find directory matching kvantum_theme name, copy it
      theme_clone_fresh /tmp/theme-kvantum "$kvantum_repo"
      theme_run "create kvantum dir" mkdir -p "$HOME/.config/Kvantum"
      theme_run "remove previous kvantum theme dir" rm -rf "$HOME/.config/Kvantum/${kvantum_theme}"
      if [[ "${THEME_DRY_RUN}" == "1" ]]; then
        echo "[dry-run] find and copy kvantum theme dir ${kvantum_theme}"
      else
        local src_dir
        src_dir="$(find /tmp/theme-kvantum -maxdepth 3 -type d -name "${kvantum_theme}" | head -1)"
        if [[ -n "$src_dir" ]]; then
          cp -r "$src_dir" "$HOME/.config/Kvantum/"
        else
          theme_warn "Kvantum theme dir '${kvantum_theme}' not found in repo; skipping"
        fi
        rm -rf /tmp/theme-kvantum
      fi
      ;;

    tarball_release)
      local base_url resolved_file
      base_url="$(theme_context_get "kvantum_config.base_url")"
      resolved_file="$(theme_context_get "kvantum_config.resolved_file")"
      kvantum_theme="$(theme_context_get "kvantum_config.resolved_theme")"
      theme_run "create kvantum dir" mkdir -p "$HOME/.config/Kvantum"
      theme_run "remove previous kvantum theme dir" rm -rf "$HOME/.config/Kvantum/${kvantum_theme}"
      if [[ "${THEME_DRY_RUN}" == "1" ]]; then
        echo "[dry-run] curl ${base_url}/${resolved_file} | tar -xz -C ~/.config/Kvantum/"
      else
        curl -fLso /tmp/theme-kvantum.tar.gz "${base_url}/${resolved_file}"
        tar -xz -C "$HOME/.config/Kvantum/" -f /tmp/theme-kvantum.tar.gz
        rm -f /tmp/theme-kvantum.tar.gz
      fi
      ;;

    "")
      theme_warn "kvantum_config.method is empty; skipping kvantum install"
      return 0
      ;;

    *)
      theme_warn "Unknown kvantum method '${kvantum_method}'; skipping"
      return 0
      ;;
  esac

  theme_run_shell "activate kvantum theme" "printf '[General]\ntheme=${kvantum_theme}\n' > ${HOME}/.config/Kvantum/kvantum.kvconfig"
  theme_run "set KDE widget style" kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
}

# ---------------------------------------------------------------------------
# GTK install — dispatches on gtk_install_config.method
# ---------------------------------------------------------------------------

_kde_install_gtk() {
  local gtk_method
  gtk_method="$(theme_context_get "gtk_install_config.method")"

  case "$gtk_method" in
    catppuccin_install_py)
      local gtk_version flavor accent
      gtk_version="$(theme_context_get "gtk_install_config.version")"
      flavor="$(theme_context_get "flavor")"
      accent="$(theme_context_get "accent")"
      if [[ "${THEME_DRY_RUN}" == "1" ]]; then
        echo "[dry-run] catppuccin/gtk installer for ${flavor}/${accent} (${gtk_version})"
      else
        curl -LsSo /tmp/catppuccin-gtk-install.py \
          "https://raw.githubusercontent.com/catppuccin/gtk/${gtk_version}/install.py"
        rm -rf "$HOME/.config/gtk-4.0"
        python3 /tmp/catppuccin-gtk-install.py "$flavor" "$accent" --link
        rm -f /tmp/catppuccin-gtk-install.py
      fi
      ;;

    gtk_repo)
      local gtk_repo
      gtk_repo="$(theme_context_get "gtk_install_config.repo")"
      theme_clone_fresh /tmp/theme-gtk "$gtk_repo"
      if [[ "${THEME_DRY_RUN}" == "1" ]]; then
        echo "[dry-run] install gtk theme from ${gtk_repo} (install.sh or copy to ~/.themes)"
      else
        mkdir -p "$HOME/.themes"
        if [[ -x /tmp/theme-gtk/install.sh ]]; then
          (cd /tmp/theme-gtk && ./install.sh)
        else
          for theme_dir in /tmp/theme-gtk/*/; do
            [[ -d "$theme_dir" ]] || continue
            local theme_name
            theme_name="$(basename "$theme_dir")"
            rm -rf "$HOME/.themes/${theme_name}"
            cp -r "$theme_dir" "$HOME/.themes/"
          done
        fi
        rm -rf /tmp/theme-gtk
      fi
      ;;

    none|"")
      theme_info "GTK install skipped (method: ${gtk_method:-none})"
      return 0
      ;;

    *)
      theme_warn "Unknown gtk install method '${gtk_method}'; skipping"
      return 0
      ;;
  esac

  local gtk_theme
  gtk_theme="$(theme_context_get "derived.gtk_theme" 2>/dev/null)" || gtk_theme=""

  if command -v flatpak &>/dev/null; then
    theme_run "flatpak gtk3 config access" sudo flatpak override --filesystem=xdg-config/gtk-3.0:ro
    theme_run "flatpak gtk4 config access" sudo flatpak override --filesystem=xdg-config/gtk-4.0:ro
    theme_run "flatpak themes access" sudo flatpak override --filesystem=~/.themes:ro
    theme_run "flatpak icons access" sudo flatpak override --filesystem=~/.icons:ro
    if [[ -n "$gtk_theme" ]]; then
      theme_run "flatpak gtk theme" sudo flatpak override --env="GTK_THEME=${gtk_theme}"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Papirus folder accents — only when derived.papirus_folder_code is set
# ---------------------------------------------------------------------------

_kde_install_papirus() {
  local papirus_folder
  papirus_folder="$(theme_context_get "derived.papirus_folder_code" 2>/dev/null)" || papirus_folder=""
  [[ -n "$papirus_folder" ]] || return 0

  theme_clone_fresh /tmp/catppuccin-papirus https://github.com/catppuccin/papirus-folders.git
  theme_run "copy papirus folder accents" sudo cp -r /tmp/catppuccin-papirus/src/* /usr/share/icons/Papirus/
  [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/catppuccin-papirus

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] papirus-folders -C ${papirus_folder} --theme Papirus-Dark"
  else
    curl -fLo /tmp/papirus-folders \
      "https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders"
    chmod +x /tmp/papirus-folders
    /tmp/papirus-folders -C "$papirus_folder" --theme Papirus-Dark
    rm -f /tmp/papirus-folders
  fi
}

# ---------------------------------------------------------------------------
# Main adapter entry point
# ---------------------------------------------------------------------------

theme_apply_kde_adapter() {
  local theme flavor accent
  theme="$(theme_context_get "theme")"
  flavor="$(theme_context_get "flavor")"
  accent="$(theme_context_get "accent")"

  local kde_scheme lookandfeel lockscreen_theme
  kde_scheme="$(theme_context_get "derived.kde_scheme")"
  lookandfeel="$(theme_context_get "derived.kde_lookandfeel")"
  lockscreen_theme="$(theme_context_get "derived.kscreenlock_theme")"

  theme_info "Applying KDE theme (${theme}/${flavor}/${accent})"

  _kde_install_plasma
  theme_run "plasma colorscheme" plasma-apply-colorscheme "$kde_scheme"
  theme_run "lock screen greeter theme" kwriteconfig6 --file kscreenlockerrc \
    --group Greeter --key Theme "$lockscreen_theme"

  _kde_install_kvantum
  _kde_install_gtk
  _kde_install_papirus

  theme_run "set icon theme" kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark
  theme_run "set terminal app" kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
  theme_run "set terminal service" kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop

  theme_render_template "${THEME_REPO_DIR}/themes/templates/gtk-3.0-settings.ini.tpl" \
    "$HOME/.config/gtk-3.0/settings.ini"

  # Update desktop wallpaper rotation to the theme-specific folder (requires live session)
  if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    if [[ "${THEME_DRY_RUN}" == "1" ]]; then
      echo "[dry-run] apply-wallpaper-rotation.sh --theme=${theme}"
    else
      bash "${THEME_LIB_DIR}/../apply-wallpaper-rotation.sh" "--theme=${theme}" \
        || theme_warn "Wallpaper rotation update failed; will apply on next login"
    fi
  else
    theme_info "No desktop session detected; wallpaper rotation deferred to next login"
  fi

  theme_info "KDE/Kvantum/GTK/icons adapter completed"
}
