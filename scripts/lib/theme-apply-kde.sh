#!/usr/bin/env bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/theme-common.sh"

theme_apply_kde_adapter() {
  local theme flavor accent
  theme="$(theme_context_get "theme")"
  flavor="$(theme_context_get "flavor")"
  accent="$(theme_context_get "accent")"

  if [[ "$theme" != "catppuccin" ]]; then
    theme_err "kde adapter currently supports only 'catppuccin'"
    return 1
  fi

  local flavor_idx accent_idx
  flavor_idx="$(theme_context_get "kde_installer_index.flavor.${flavor}")"
  accent_idx="$(theme_context_get "kde_installer_index.accent.${accent}")"

  local kde_scheme lookandfeel lockscreen_theme kvantum_theme gtk_theme gtk_cursor_theme papirus_folder
  kde_scheme="$(theme_context_get "derived.kde_scheme")"
  lookandfeel="$(theme_context_get "derived.kde_lookandfeel")"
  lockscreen_theme="$(theme_context_get "derived.kscreenlock_theme")"
  kvantum_theme="$(theme_context_get "derived.kvantum_theme")"
  gtk_theme="$(theme_context_get "derived.gtk_theme")"
  gtk_cursor_theme="$(theme_context_get "derived.gtk_cursor_theme")"
  papirus_folder="$(theme_context_get "derived.papirus_folder_code")"

  theme_info "Applying KDE theme (${theme}/${flavor}/${accent})"

  theme_clone_fresh /tmp/catppuccin-kde https://github.com/catppuccin/kde
  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] run catppuccin/kde install.sh ${flavor_idx} ${accent_idx} 1"
  else
    (
      cd /tmp/catppuccin-kde
      printf 'y\ny\n' | ./install.sh "$flavor_idx" "$accent_idx" 1
    )
  fi
  [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/catppuccin-kde

  theme_run "plasma colorscheme" plasma-apply-colorscheme "$kde_scheme"
  theme_run "plasma lookandfeel" plasma-apply-lookandfeel --apply "$lookandfeel"
  theme_run "lock screen greeter theme" kwriteconfig6 --file kscreenlockerrc --group Greeter --key Theme "$lockscreen_theme"

  theme_clone_fresh /tmp/catppuccin-kvantum https://github.com/catppuccin/kvantum.git
  theme_run "create kvantum dir" mkdir -p "$HOME/.config/Kvantum"
  theme_run "install kvantum theme files" cp -r "/tmp/catppuccin-kvantum/themes/${kvantum_theme}" "$HOME/.config/Kvantum/"
  [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/catppuccin-kvantum
  theme_run "activate kvantum theme" kvantummanager --set "$kvantum_theme"
  theme_run "set KDE widget style" kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] catppuccin/gtk installer for ${flavor}/${accent}"
  else
    curl -LsSo /tmp/catppuccin-gtk-install.py "https://raw.githubusercontent.com/catppuccin/gtk/v1.0.3/install.py"
    rm -rf "$HOME/.config/gtk-4.0"
    python3 /tmp/catppuccin-gtk-install.py "$flavor" "$accent" --link
    rm -f /tmp/catppuccin-gtk-install.py
  fi

  if command -v flatpak &>/dev/null; then
    theme_run "flatpak gtk3 config access" sudo flatpak override --filesystem=xdg-config/gtk-3.0:ro
    theme_run "flatpak gtk4 config access" sudo flatpak override --filesystem=xdg-config/gtk-4.0:ro
    theme_run "flatpak themes access" sudo flatpak override --filesystem=~/.themes:ro
    theme_run "flatpak icons access" sudo flatpak override --filesystem=~/.icons:ro
    theme_run "flatpak gtk theme" sudo flatpak override --env="GTK_THEME=${gtk_theme}"
  fi

  theme_clone_fresh /tmp/catppuccin-papirus https://github.com/catppuccin/papirus-folders.git
  theme_run "copy papirus folder accents" sudo cp -r /tmp/catppuccin-papirus/src/* /usr/share/icons/Papirus/
  [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/catppuccin-papirus

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] papirus-folders -C ${papirus_folder} --theme Papirus-Dark"
  else
    curl -fLo /tmp/papirus-folders "https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders"
    chmod +x /tmp/papirus-folders
    /tmp/papirus-folders -C "$papirus_folder" --theme Papirus-Dark
    rm -f /tmp/papirus-folders
  fi

  theme_run "set icon theme" kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark
  theme_run "set terminal app" kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
  theme_run "set terminal service" kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop

  theme_render_template "${THEME_REPO_DIR}/themes/templates/gtk-3.0-settings.ini.tpl" "$HOME/.config/gtk-3.0/settings.ini"

  theme_info "KDE/Kvantum/GTK/icons adapter completed"
}
