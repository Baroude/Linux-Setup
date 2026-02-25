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
  ca-certificates
  gtk2-engines-murrine
  gnome-themes-extra
  papirus-icon-theme
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

  local latest_tag
  latest_tag="$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | grep -m1 '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')"

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

  local target_font="/usr/share/fonts/iosevka/iosevka.ttc"
  if [ -f "$target_font" ]; then
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  curl -fL https://github.com/be5invis/Iosevka/releases/download/v32.3.1/super-ttc-iosevka-32.3.1.zip -o "$tmp_dir/iosevka.zip"
  unzip -q "$tmp_dir/iosevka.zip" -d "$tmp_dir"

  sudo mkdir -p /usr/share/fonts/iosevka
  sudo mv "$tmp_dir/iosevka.ttc" "$target_font"
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

  if [ -f "$SCRIPT_DIR/images/forest.jpg" ]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$SCRIPT_DIR/images/forest.jpg"
  fi

  # Install and configure GNOME Shell extensions (requires live session)
  local ext_script="$SCRIPT_DIR/gnome/gnome-extensions.sh"
  if [ -f "$ext_script" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    log "Running GNOME extension setup"
    bash "$ext_script"
  else
    log "Skipping GNOME extensions (no display session or script missing)"
    log "Run manually after login: bash $ext_script"
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
  apply_catppuccin_theme
  remove_legacy_nvim_cron

  log "Setup complete. Run '$SCRIPT_DIR/install' to apply dotfiles."
}

main "$@"
