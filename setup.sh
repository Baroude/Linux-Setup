#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEBIAN_FRONTEND=noninteractive

APT_PACKAGES=(
  vim
  git
  curl
  zsh
  vlc
  filezilla
  python3-pip
  imagemagick
  build-essential
  clangd
  ninja-build
  gettext
  libtool
  libtool-bin
  autoconf
  automake
  cmake
  g++
  pkg-config
  unzip
  doxygen
  kitty
  swayidle
  gnome-shell-extensions
  ca-certificates
  gtk2-engines-murrine
  gnome-themes-extra
  papirus-icon-theme
  libncursesw5-dev
)

LSP_NPM_PACKAGES=(
  typescript
  typescript-language-server
  bash-language-server
  pyright
)

log() {
  printf '\n==> %s\n' "$*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

clone_if_missing() {
  local repo_url="$1"
  local destination="$2"

  if [ ! -d "$destination" ]; then
    git clone --depth 1 "$repo_url" "$destination"
  fi
}

install_apt_packages() {
  log "Updating package index"
  sudo apt update -y

  log "Upgrading installed packages"
  sudo apt upgrade -y

  log "Installing base packages"
  sudo apt install -y "${APT_PACKAGES[@]}"
}

install_node_lts() {
  log "Installing Node.js LTS from NodeSource"
  local node_setup_script
  node_setup_script="$(mktemp)"

  curl -fsSL https://deb.nodesource.com/setup_lts.x -o "$node_setup_script"
  sudo -E bash "$node_setup_script"
  rm -f "$node_setup_script"

  sudo apt install -y nodejs
}

install_neovim_stable() {
  log "Installing Neovim stable release"

  local api_json latest_tag
  api_json="$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest)"
  latest_tag="$(printf '%s' "$api_json" | grep -m1 '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"

  if [ -z "$latest_tag" ]; then
    echo "Failed to resolve latest Neovim release tag" >&2
    exit 1
  fi

  local current_version
  current_version="$(nvim --version 2>/dev/null | head -n1 | awk '{print $2}' | sed 's/^v//' || true)"

  if [ "$current_version" = "${latest_tag#v}" ]; then
    log "Neovim ${latest_tag} already installed"
    return
  fi

  local arch
  case "$(uname -m)" in
    x86_64)
      arch="x86_64"
      ;;
    aarch64|arm64)
      arch="arm64"
      ;;
    *)
      echo "Unsupported architecture for Neovim install: $(uname -m)" >&2
      exit 1
      ;;
  esac

  local tarball_url
  tarball_url="https://github.com/neovim/neovim/releases/download/${latest_tag}/nvim-linux-${arch}.tar.gz"

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  curl -fL "$tarball_url" -o "$tmp_dir/nvim.tar.gz"
  tar -xzf "$tmp_dir/nvim.tar.gz" -C "$tmp_dir"

  local extracted_dir
  extracted_dir="$(find "$tmp_dir" -maxdepth 1 -type d -name 'nvim-linux-*' | head -n1)"

  if [ -z "$extracted_dir" ]; then
    echo "Neovim archive extraction failed" >&2
    rm -rf "$tmp_dir"
    exit 1
  fi

  sudo rm -rf /opt/nvim
  sudo mv "$extracted_dir" /opt/nvim
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

  rm -rf "$tmp_dir"
}

install_lsp_tools() {
  log "Installing global language servers"
  sudo npm install -g "${LSP_NPM_PACKAGES[@]}"
}

install_cbonsai() {
  if command_exists cbonsai; then
    return
  fi

  log "Installing cbonsai"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  git clone --depth 1 https://gitlab.com/jallbrit/cbonsai "$tmp_dir/cbonsai"
  (
    cd "$tmp_dir/cbonsai"
    make
    sudo make install
  )

  rm -rf "$tmp_dir"
}

install_oh_my_zsh() {
  log "Configuring zsh + oh-my-zsh"

  if command_exists zsh && [ "${SHELL:-}" != "$(command -v zsh)" ]; then
    chsh -s "$(command -v zsh)" "$USER" || true
  fi

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi

  mkdir -p "$HOME/.oh-my-zsh/plugins"
  clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/plugins/zsh-syntax-highlighting"
  clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$HOME/.oh-my-zsh/plugins/zsh-autosuggestions"
}

install_starship() {
  if command_exists starship; then
    return
  fi

  log "Installing Starship prompt"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
}

install_iosevka_font() {
  log "Installing Iosevka font"

  local font_dir="/usr/share/fonts/iosevka"
  if [ -f "$font_dir/Iosevka-Regular.ttc" ]; then
    return
  fi

  local latest_tag version tmp_dir
  latest_tag="$(curl -fsSI https://github.com/be5invis/Iosevka/releases/latest \
    | grep -i '^location:' | sed 's|.*/||' | tr -d '\r\n')"
  version="${latest_tag#v}"

  if [ -z "$version" ]; then
    echo "Failed to resolve latest Iosevka release tag" >&2
    return 1
  fi

  tmp_dir="$(mktemp -d)"

  curl -fL "https://github.com/be5invis/Iosevka/releases/download/${latest_tag}/PkgTTC-Iosevka-${version}.zip" -o "$tmp_dir/iosevka.zip"
  unzip -q "$tmp_dir/iosevka.zip" -d "$tmp_dir"

  sudo mkdir -p "$font_dir"
  sudo mv "$tmp_dir"/Iosevka-*.ttc "$font_dir/"
  rm -rf "$tmp_dir"

  fc-cache -f
}

install_symbols_nerd_font() {
  log "Installing Symbols Nerd Font Mono"

  local font_dir="$HOME/.local/share/fonts/nerd-fonts"
  if [ -f "$font_dir/SymbolsNerdFontMono-Regular.ttf" ]; then
    return
  fi

  local latest_tag tmp_dir
  latest_tag="$(curl -fsSI https://github.com/ryanoasis/nerd-fonts/releases/latest \
    | grep -i '^location:' | sed 's|.*/||' | tr -d '\r\n')"

  if [ -z "$latest_tag" ]; then
    echo "Failed to resolve latest Nerd Fonts release tag" >&2
    return 1
  fi

  tmp_dir="$(mktemp -d)"
  curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/${latest_tag}/NerdFontsSymbolsOnly.zip" \
    -o "$tmp_dir/symbols.zip"
  unzip -q "$tmp_dir/symbols.zip" -d "$tmp_dir"

  mkdir -p "$font_dir"
  mv "$tmp_dir"/SymbolsNerdFont*.ttf "$font_dir/"
  rm -rf "$tmp_dir"

  fc-cache -f
}

apply_catppuccin_theme() {
  if ! command_exists gsettings; then
    return
  fi

  log "Applying Catppuccin Mocha GTK theme"

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  git clone --depth 1 https://github.com/Fausto-Korpsvart/Catppuccin-GTK-Theme "$tmp_dir/Catppuccin-GTK-Theme"
  (
    cd "$tmp_dir/Catppuccin-GTK-Theme/themes"
    ./install.sh -t blue -c dark -s standard -l
  )

  rm -rf "$tmp_dir"

  gsettings set org.gnome.desktop.interface gtk-theme "Catppuccin-Blue-Dark"
  gsettings set org.gnome.desktop.wm.preferences theme "Catppuccin-Blue-Dark"

  gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
  if command_exists papirus-folders; then
    papirus-folders -C cat-mocha-blue --theme Papirus-Dark || true
  fi

  mkdir -p "$HOME/.icons"
  local cursor_zip="$HOME/.icons/catppuccin-mocha-blue-cursors.zip"
  if [ ! -d "$HOME/.icons/catppuccin-mocha-blue-cursors" ]; then
    curl -fL https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-mocha-blue-cursors.zip -o "$cursor_zip"
    unzip -q "$cursor_zip" -d "$HOME/.icons"
    rm -f "$cursor_zip"
  fi

  gsettings set org.gnome.desktop.interface cursor-theme "catppuccin-mocha-blue-cursors"

  if [ -f "$SCRIPT_DIR/images/evening-sky.png" ]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$SCRIPT_DIR/images/evening-sky.png"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$SCRIPT_DIR/images/evening-sky.png"
    gsettings set org.gnome.desktop.screensaver picture-uri "file://$SCRIPT_DIR/images/evening-sky.png"
  fi

  # Enable the User Themes GNOME Shell extension and apply Catppuccin shell theme
  # (styles the lock screen, top bar, and notification shade)
  local user_theme_ext="user-theme@gnome-shell-extensions.gcampax.github.com"
  local current_exts
  current_exts="$(gsettings get org.gnome.shell enabled-extensions 2>/dev/null || echo "@as []")"
  if ! printf '%s' "$current_exts" | grep -q "$user_theme_ext"; then
    if [ "$current_exts" = "@as []" ] || [ "$current_exts" = "[]" ]; then
      gsettings set org.gnome.shell enabled-extensions "['$user_theme_ext']"
    else
      local trimmed="${current_exts%]}"
      gsettings set org.gnome.shell enabled-extensions "${trimmed}, '$user_theme_ext']"
    fi
  fi
  gsettings set org.gnome.shell.extensions.user-theme name "Catppuccin-Blue-Dark" 2>/dev/null || true
}

set_user_avatar() {
  local avatar_src="$SCRIPT_DIR/fastfetch/debian-cattpuccin.png"

  if [ ! -f "$avatar_src" ]; then
    return
  fi

  log "Setting user avatar (Catppuccin Debian logo)"

  local accounts_icon="/var/lib/AccountsService/icons/$USER"
  local accounts_conf="/var/lib/AccountsService/users/$USER"

  sudo mkdir -p "/var/lib/AccountsService/icons" "/var/lib/AccountsService/users"
  sudo cp "$avatar_src" "$accounts_icon"
  sudo chmod 644 "$accounts_icon"

  local tmp_conf
  tmp_conf="$(mktemp)"

  if sudo test -f "$accounts_conf"; then
    # Preserve existing entries, remove any stale Icon= line
    sudo grep -v "^Icon=" "$accounts_conf" > "$tmp_conf" 2>/dev/null || true
    if ! grep -q "^\[User\]" "$tmp_conf"; then
      printf '[User]\n' >> "$tmp_conf"
    fi
    sed -i "/^\[User\]/a Icon=$accounts_icon" "$tmp_conf"
  else
    printf '[User]\nIcon=%s\n' "$accounts_icon" > "$tmp_conf"
  fi

  sudo cp "$tmp_conf" "$accounts_conf"
  sudo chmod 644 "$accounts_conf"
  rm -f "$tmp_conf"

  # ~/.face for apps that read it directly (e.g. some display managers)
  cp "$avatar_src" "$HOME/.face"
}

install_swayidle() {
  if ! command_exists swayidle; then
    return
  fi

  log "Configuring swayidle idle lock"

  local service_dir="$HOME/.config/systemd/user"
  mkdir -p "$service_dir"

  cp "$SCRIPT_DIR/swayidle/swayidle.service" "$service_dir/swayidle.service"

  systemctl --user daemon-reload
  systemctl --user enable swayidle.service || true
  systemctl --user restart swayidle.service || true

  # Disable GNOME's own idle-triggered auto-lock; swayidle owns idle detection
  # and calls loginctl lock-session which triggers GNOME's lock screen directly.
  if command_exists gsettings; then
    gsettings set org.gnome.desktop.screensaver lock-enabled false 2>/dev/null || true
    gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null || true
  fi
}

remove_legacy_nvim_cron() {
  log "Removing legacy Neovim auto-build cron job"

  local current_cron
  current_cron="$(crontab -l 2>/dev/null || true)"

  if [ -z "$current_cron" ]; then
    return
  fi

  local filtered_cron
  filtered_cron="$(printf '%s\n' "$current_cron" | grep -v 'nvimUpdate.sh' || true)"

  if [ "$filtered_cron" = "$current_cron" ]; then
    return
  fi

  if [ -n "$filtered_cron" ]; then
    printf '%s\n' "$filtered_cron" | crontab -
  else
    crontab -r || true
  fi
}

main() {
  install_apt_packages
  install_node_lts
  install_neovim_stable
  install_lsp_tools
  install_cbonsai
  install_oh_my_zsh
  install_starship
  install_iosevka_font
  install_symbols_nerd_font
  apply_catppuccin_theme
  set_user_avatar
  install_swayidle
  remove_legacy_nvim_cron

  log "Setup complete. Run '$SCRIPT_DIR/install' to apply dotfiles."
}

main "$@"
