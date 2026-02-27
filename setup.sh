#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEBIAN_FRONTEND=noninteractive

# Catppuccin variant to apply. Override by exporting this variable before running.
# Valid values: mocha-blue, mocha-mauve, mocha-teal,
#               macchiato-blue, macchiato-mauve, macchiato-teal
CATPPUCCIN_VARIANT="${CATPPUCCIN_VARIANT:-mocha-blue}"

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
  gnome-shell-extensions
  ca-certificates
  gtk2-engines-murrine
  gnome-themes-extra
  sassc
  pipx
  libncursesw5-dev
  # Modern CLI replacements
  bat
  fd-find
  ripgrep
  fzf
  eza
  # System monitoring
  btop
  fastfetch
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
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

  log "Upgrading installed packages"
  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"

  log "Installing base packages"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "${APT_PACKAGES[@]}"
}

install_node_lts() {
  log "Installing Node.js LTS from NodeSource"
  local node_setup_script
  node_setup_script="$(mktemp)"

  curl -fsSL https://deb.nodesource.com/setup_lts.x -o "$node_setup_script"
  sudo -E bash "$node_setup_script"
  rm -f "$node_setup_script"

  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
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
    sudo usermod -s "$(command -v zsh)" "$USER" || true
  fi

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi

  mkdir -p "$HOME/.oh-my-zsh/plugins"
  clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.oh-my-zsh/plugins/zsh-syntax-highlighting"
  clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$HOME/.oh-my-zsh/plugins/zsh-autosuggestions"
  clone_if_missing https://github.com/MichaelAquilina/zsh-you-should-use.git "$HOME/.oh-my-zsh/plugins/you-should-use"
}

install_starship() {
  if command_exists starship; then
    return
  fi

  log "Installing Starship prompt"
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
}

install_monaspace_nerd_font() {
  log "Installing Monaspace Neon Nerd Font"

  local font_dir="$HOME/.local/share/fonts/nerd-fonts/monaspace-neon"
  if [ -f "$font_dir/MonaspaceNeonNerdFont-Regular.otf" ]; then
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
  # nerd-fonts ships all five Monaspace variants in a single Monaspace.zip
  curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/${latest_tag}/Monaspace.zip" \
    -o "$tmp_dir/Monaspace.zip"
  unzip -q "$tmp_dir/Monaspace.zip" -d "$tmp_dir/monaspace"

  mkdir -p "$font_dir"
  # Extract only the Neon variant (NF regular/bold/italic/bolditalic)
  find "$tmp_dir/monaspace" -name "MonaspaceNeonNerdFont-*.otf" -exec mv {} "$font_dir/" \;
  rm -rf "$tmp_dir"

  fc-cache -f
}

install_papirus_icon_theme() {
  log "Installing latest papirus-icon-theme from GitHub"
  local install_script
  install_script="$(mktemp)"
  curl -fsSL https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-icon-theme/master/install.sh \
    -o "$install_script"
  sh "$install_script"
  rm -f "$install_script"
}

install_papirus_folders() {
  log "Installing/updating papirus-folders"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  git clone --depth 1 https://github.com/PapirusDevelopmentTeam/papirus-folders \
    "$tmp_dir/papirus-folders"
  (
    cd "$tmp_dir/papirus-folders"
    sudo make install
  )

  rm -rf "$tmp_dir"
}

install_zoxide() {
  if command_exists zoxide; then
    return
  fi

  log "Installing zoxide"
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

install_delta() {
  if command_exists delta; then
    return
  fi

  log "Installing delta (git pager)"
  local latest_tag tmp_dir arch
  latest_tag="$(curl -fsSI https://github.com/dandavison/delta/releases/latest \
    | grep -i '^location:' | sed 's|.*/||' | tr -d '\r\n')"

  case "$(uname -m)" in
    x86_64)  arch="x86_64" ;;
    aarch64) arch="aarch64" ;;
    *) echo "Unsupported arch for delta: $(uname -m)" >&2; return 1 ;;
  esac

  tmp_dir="$(mktemp -d)"
  curl -fL "https://github.com/dandavison/delta/releases/download/${latest_tag}/delta-${latest_tag}-${arch}-unknown-linux-gnu.tar.gz" \
    -o "$tmp_dir/delta.tar.gz"
  tar -xzf "$tmp_dir/delta.tar.gz" -C "$tmp_dir" --strip-components=1
  sudo mv "$tmp_dir/delta" /usr/local/bin/delta
  rm -rf "$tmp_dir"
}

apply_catppuccin_theme() {
  if ! command_exists gsettings; then
    return
  fi

  log "Applying Catppuccin theme (variant: ${CATPPUCCIN_VARIANT})"

  # ── Variant lookup ────────────────────────────────────────────────────────
  # Sets: FLAVOR  (mocha|macchiato)
  #       ACCENT  (Blue|Mauve|Teal)          — capitalised, for theme dir names
  #       ACCENT_LOWER (blue|mauve|teal)     — lower-case, for install.sh -t flag
  #       PAPIRUS_COLOR                      — nearest papirus-folders color name
  #       ACCENT_HEX  (#rrggbb)              — GTK accent colour
  #       BORDER_HEX  (#rrggbb)              — dock neon-border colour (same hue)
  #       GTK_THEME_NAME                     — directory name under ~/.themes
  #       INSTALL_TWEAKS                     — extra flags for install.sh (empty or --tweaks macchiato)
  local FLAVOR ACCENT ACCENT_LOWER ACCENT_HEX BORDER_HEX GTK_THEME_NAME INSTALL_TWEAKS PAPIRUS_COLOR
  # PAPIRUS_COLOR maps Catppuccin accents to the nearest papirus-folders color.
  # papirus-folders does not have 'mauve' — 'violet' is the closest match.
  case "${CATPPUCCIN_VARIANT}" in
    mocha-blue)
      FLAVOR="mocha";      ACCENT="Blue";  ACCENT_LOWER="blue";
      ACCENT_HEX="#89b4fa"; BORDER_HEX="#89b4fa"
      GTK_THEME_NAME="Catppuccin-Blue-Dark"; INSTALL_TWEAKS=""
      PAPIRUS_COLOR="blue" ;;
    mocha-mauve)
      FLAVOR="mocha";      ACCENT="Mauve"; ACCENT_LOWER="mauve";
      ACCENT_HEX="#cba6f7"; BORDER_HEX="#cba6f7"
      GTK_THEME_NAME="Catppuccin-Mauve-Dark"; INSTALL_TWEAKS=""
      PAPIRUS_COLOR="violet" ;;
    mocha-teal)
      FLAVOR="mocha";      ACCENT="Teal";  ACCENT_LOWER="teal";
      ACCENT_HEX="#94e2d5"; BORDER_HEX="#94e2d5"
      GTK_THEME_NAME="Catppuccin-Teal-Dark"; INSTALL_TWEAKS=""
      PAPIRUS_COLOR="teal" ;;
    macchiato-blue)
      FLAVOR="macchiato";  ACCENT="Blue";  ACCENT_LOWER="blue";
      ACCENT_HEX="#8aadf4"; BORDER_HEX="#8aadf4"
      GTK_THEME_NAME="Catppuccin-Blue-Dark-Macchiato"; INSTALL_TWEAKS="--tweaks macchiato"
      PAPIRUS_COLOR="blue" ;;
    macchiato-mauve)
      FLAVOR="macchiato";  ACCENT="Mauve"; ACCENT_LOWER="mauve";
      ACCENT_HEX="#c6a0f6"; BORDER_HEX="#c6a0f6"
      GTK_THEME_NAME="Catppuccin-Mauve-Dark-Macchiato"; INSTALL_TWEAKS="--tweaks macchiato"
      PAPIRUS_COLOR="violet" ;;
    macchiato-teal)
      FLAVOR="macchiato";  ACCENT="Teal";  ACCENT_LOWER="teal";
      ACCENT_HEX="#8bd5ca"; BORDER_HEX="#8bd5ca"
      GTK_THEME_NAME="Catppuccin-Teal-Dark-Macchiato"; INSTALL_TWEAKS="--tweaks macchiato"
      PAPIRUS_COLOR="teal" ;;
    *)
      echo "ERROR: Unknown CATPPUCCIN_VARIANT '${CATPPUCCIN_VARIANT}'." >&2
      echo "       Valid values: mocha-blue, mocha-mauve, mocha-teal," >&2
      echo "                     macchiato-blue, macchiato-mauve, macchiato-teal" >&2
      exit 1 ;;
  esac

  # Precompute Open Bar's array-of-strings colour format (0.000–1.000 per channel).
  # Used both by _write_variant_dconf (dconf keyfile) and the CSS injection.
  local r_int g_int b_int r_f g_f b_f rgb_arr
  r_int=$((16#${ACCENT_HEX:1:2}))
  g_int=$((16#${ACCENT_HEX:3:2}))
  b_int=$((16#${ACCENT_HEX:5:2}))
  r_f=$(awk "BEGIN { printf \"%.3f\", ${r_int}/255 }")
  g_f=$(awk "BEGIN { printf \"%.3f\", ${g_int}/255 }")
  b_f=$(awk "BEGIN { printf \"%.3f\", ${b_int}/255 }")
  rgb_arr="['${r_f}','${g_f}','${b_f}']"

  # ── GTK theme ─────────────────────────────────────────────────────────────
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  git clone --depth 1 https://github.com/Fausto-Korpsvart/Catppuccin-GTK-Theme "$tmp_dir/Catppuccin-GTK-Theme"
  (
    cd "$tmp_dir/Catppuccin-GTK-Theme/themes"
    # shellcheck disable=SC2086  — INSTALL_TWEAKS is intentionally word-split
    ./install.sh -t "${ACCENT_LOWER}" -c dark -s standard -l ${INSTALL_TWEAKS}
  )

  rm -rf "$tmp_dir"

  gsettings set org.gnome.desktop.interface gtk-theme "${GTK_THEME_NAME}"
  gsettings set org.gnome.desktop.wm.preferences theme "${GTK_THEME_NAME}"

  # ── Window button layout: macOS order (left side) ─────────────────────────
  gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'

  # ── GTK window button CSS: traffic-light circles ──────────────────────────
  _write_gtk_buttons_css "${FLAVOR}"

  # ── Icon theme ────────────────────────────────────────────────────────────
  gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
  if command_exists papirus-folders; then
    papirus-folders -C "${PAPIRUS_COLOR}" --theme Papirus-Dark
  else
    echo "WARNING: papirus-folders not found — run install_papirus_folders() first" >&2
  fi

  # ── Cursor theme ──────────────────────────────────────────────────────────
  local cursor_name="catppuccin-${FLAVOR}-${ACCENT_LOWER}-cursors"
  mkdir -p "$HOME/.icons"
  local cursor_zip="$HOME/.icons/${cursor_name}.zip"
  if [ ! -d "$HOME/.icons/${cursor_name}" ]; then
    curl -fL "https://github.com/catppuccin/cursors/releases/download/v2.0.0/${cursor_name}.zip" \
      -o "$cursor_zip"
    unzip -q "$cursor_zip" -d "$HOME/.icons"
    rm -f "$cursor_zip"
  fi

  gsettings set org.gnome.desktop.interface cursor-theme "${cursor_name}"

  # ── Wallpaper ─────────────────────────────────────────────────────────────
  if [ -f "$SCRIPT_DIR/images/evening-sky.png" ]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$SCRIPT_DIR/images/evening-sky.png"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$SCRIPT_DIR/images/evening-sky.png"
    gsettings set org.gnome.desktop.screensaver picture-uri "file://$SCRIPT_DIR/images/evening-sky.png"
  fi

  # ── User Themes extension ─────────────────────────────────────────────────
  # Enables the User Themes GNOME Shell extension and applies the Catppuccin
  # shell theme (styles the lock screen, top bar, and notification shade).
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
  gsettings set org.gnome.shell.extensions.user-theme name "${GTK_THEME_NAME}" 2>/dev/null || true

  # ── Dock neon-border CSS ──────────────────────────────────────────────────
  # Generate dock-neon-border.css with the correct border colour for this
  # variant, then inject it into the active GNOME Shell theme.
  # The Catppuccin install script places the theme in ~/.themes.
  local custom_css="$SCRIPT_DIR/gnome/dock-neon-border.css"
  _write_dock_neon_border_css "${BORDER_HEX}" "${CATPPUCCIN_VARIANT}" "$custom_css"

  local theme_css="$HOME/.themes/${GTK_THEME_NAME}/gnome-shell/gnome-shell.css"
  local marker="/* dock-neon-border */"
  if [ -f "$theme_css" ] && [ -f "$custom_css" ]; then
    # Always replace any previously injected block so variant switches update
    # the colour.  The block is always appended at EOF, so deleting from the
    # marker to end-of-file cleanly removes the old version.
    if grep -qF "$marker" "$theme_css"; then
      sed -i '/\/\* dock-neon-border \*\//,$d' "$theme_css"
    fi
    log "Injecting dock neon border CSS into GNOME Shell theme"
    { echo "$marker"; cat "$custom_css"; } >> "$theme_css"

    # Force GNOME Shell to reload the theme CSS immediately so the injected
    # styles take effect without requiring a logout.
    if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && command_exists gdbus; then
      gdbus call --session \
        --dest org.gnome.Shell \
        --object-path /org/gnome/Shell \
        --method org.gnome.Shell.Eval \
        "Main.loadTheme()" >/dev/null 2>&1 || true
    fi
  fi

  # ── Idle / lock ───────────────────────────────────────────────────────────
  # Re-enable GNOME native idle lock (lock after 5 min, screen blank after 10 min)
  gsettings set org.gnome.desktop.screensaver lock-enabled true
  gsettings set org.gnome.desktop.session idle-delay 300

  # ── Variant dconf overlay ─────────────────────────────────────────────────
  # Write accent-color values into a small dconf keyfile that gnome-extensions.sh
  # loads AFTER extensions.conf.  Using dconf load (not gsettings set) means
  # the values are applied unconditionally — no dependency on extensions being
  # active or signal handlers being connected.
  _write_variant_dconf

  # ── GNOME Shell extensions ────────────────────────────────────────────────
  local ext_script="$SCRIPT_DIR/gnome/gnome-extensions.sh"
  if [ -f "$ext_script" ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    log "Running GNOME extension setup"
    bash "$ext_script"
    _apply_flatpak_theming
    _create_burn_my_windows_profile
  else
    log "Skipping GNOME extensions (no display session or script missing)"
    log "Run manually after login: bash $ext_script"
  fi
}

# Write gnome/dconf/variant-colors.conf with all accent-colour-dependent dconf
# settings for the active variant.  Loaded by gnome-extensions.sh immediately
# after extensions.conf so it always wins over the hardcoded placeholder values.
# Reads rgb_arr, ACCENT_HEX, CATPPUCCIN_VARIANT from apply_catppuccin_theme scope.
_write_variant_dconf() {
  local dest="$SCRIPT_DIR/gnome/dconf/variant-colors.conf"

  log "Writing variant dconf overrides (${CATPPUCCIN_VARIANT})"

  cat > "$dest" <<CONF
# variant-colors.conf — generated by setup.sh for ${CATPPUCCIN_VARIANT}
# Loaded by gnome-extensions.sh after extensions.conf.
# DO NOT EDIT — regenerated on every setup.sh run.

[org/gnome/shell/extensions/openbar]
bcolor=${rgb_arr}
dark-bcolor=${rgb_arr}
light-bcolor=${rgb_arr}
accent-color=${rgb_arr}
dark-accent-color=${rgb_arr}
light-accent-color=${rgb_arr}
hcolor=${rgb_arr}
# Repeat border geometry so Open Bar can't drop them via GSettings notify reaction
balpha=0.65
bwidth=1.5
bradius=12.0
neon=true
dborder=true
dbradius=14.0

[org/gnome/shell/extensions/dash-to-dock]
custom-theme-running-dots-color='${ACCENT_HEX}'
custom-theme-running-dots-border-color='${ACCENT_HEX}'

[org/gnome/shell/extensions/tilingshell]
window-border-color='${ACCENT_HEX}'
CONF
}

# Write macOS-style traffic-light window button CSS into the user GTK3/GTK4
# config directories.  Uses a marker block so the section can be replaced on
# subsequent runs without clobbering any other user CSS.
# Usage: _write_gtk_buttons_css <flavor>   (flavor = mocha | macchiato)
_write_gtk_buttons_css() {
  local flavor="$1"

  # Catppuccin Red / Yellow / Green per flavor
  local c_red c_yellow c_green c_crust
  case "${flavor}" in
    macchiato)
      c_red="#ed8796"; c_yellow="#eed49f"; c_green="#a6da95"; c_crust="#181926" ;;
    *)  # mocha (default)
      c_red="#f38ba8"; c_yellow="#f9e2af"; c_green="#a6e3a1"; c_crust="#11111b" ;;
  esac

  local marker_start="/* gtk-buttons-start */"
  local marker_end="/* gtk-buttons-end */"

  local css
  css=$(cat <<CSS
${marker_start}
/* macOS-style traffic-light window buttons — generated by setup.sh (${flavor}) */

/* Strip default chrome */
headerbar button.titlebutton,
.titlebar button.titlebutton {
  padding: 0;
  margin: 4px 3px;
  min-width: 12px;
  min-height: 12px;
  border: none;
  border-radius: 50%;
  box-shadow: none;
}

/* Hide symbolic icons by default */
headerbar button.titlebutton image,
.titlebar button.titlebutton image {
  -gtk-icon-size: 0;
  opacity: 0;
}

/* Reveal icons on titlebar hover */
headerbar:hover button.titlebutton image,
.titlebar:hover button.titlebutton image {
  opacity: 0.65;
  -gtk-icon-size: 8px;
}

/* Traffic-light fills */
headerbar button.titlebutton.close,
.titlebar button.titlebutton.close   { background: ${c_red};    color: ${c_crust}; }

headerbar button.titlebutton.minimize,
.titlebar button.titlebutton.minimize { background: ${c_yellow}; color: ${c_crust}; }

headerbar button.titlebutton.maximize,
.titlebar button.titlebutton.maximize { background: ${c_green};  color: ${c_crust}; }
${marker_end}
CSS
)

  local dir
  for dir in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
    mkdir -p "$dir"
    local dest="$dir/gtk.css"
    if [ -f "$dest" ]; then
      # Remove any previous injected block (sed range delete)
      local tmp
      tmp="$(mktemp)"
      sed "/$(printf '%s' "${marker_start}" | sed 's/[\/&]/\\&/g')/,/$(printf '%s' "${marker_end}" | sed 's/[\/&]/\\&/g')/d" "$dest" > "$tmp"
      mv "$tmp" "$dest"
    fi
    printf '%s\n' "${css}" >> "$dest"
    log "GTK button CSS written to ${dest}"
  done
}

# Write gnome/dock-neon-border.css with the given hex colour.
# Usage: _write_dock_neon_border_css <hex> <variant_name> <output_path>
_write_dock_neon_border_css() {
  local hex="$1"    # e.g. #89b4fa
  local variant="$2"
  local dest="$3"

  # Convert #rrggbb → decimal r, g, b for rgba() values in the CSS.
  local r g b
  r="$((16#${hex:1:2}))"
  g="$((16#${hex:3:2}))"
  b="$((16#${hex:5:2}))"

  cat > "$dest" <<CSS
/* gnome/dock-neon-border.css
 * Generated by setup.sh for variant: ${variant}
 * Appended to the active GNOME Shell theme by setup.sh.
 *
 * Colour: ${hex}  rgb(${r}, ${g}, ${b})
 */

/* ── Top bar — fully transparent for Open Bar Islands mode ──────────────────
 *
 * Open Bar sets bgalpha=0.0 via dconf, but the Catppuccin shell theme applies
 * its own background / background-color on #panel which can win on specificity.
 * Both shorthand and longhand are cleared here so neither survives.
 */
#panel,
#panel.solid,
#panel.translucent {
  background: transparent !important;
  background-color: transparent !important;
  box-shadow: none !important;
}

/* ── Top bar island pills — neon border + outer glow ────────────────────────
 *
 * Open Bar manages island pill borders via dconf (bcolor/balpha/bwidth/bradius).
 * This CSS fallback guarantees the correct accent border even if Open Bar drops
 * its balpha or bcolor values internally when processing a GSettings notification
 * for a colour change.  Selectors mirror what Open Bar itself targets so that
 * both rules reinforce each other and either one is sufficient.
 */
.panel-button {
  border: 1.5px solid rgba(${r}, ${g}, ${b}, 0.65) !important;
  border-radius: 12px !important;
}

.panel-button:hover,
.panel-button:focus,
.panel-button:active,
.panel-button:checked {
  border: 1.5px solid rgba(${r}, ${g}, ${b}, 0.85) !important;
}

/* ── Dock — transparent background, border preserved ────────────────────────
 *
 * Dash to Dock background-opacity=0.0 and Open Bar dbgalpha=0.0 make the
 * dock container transparent via dconf, but Dash to Dock's theming.js may
 * still write an inline background-color.  The override below ensures the
 * background stays clear while leaving the border and glow intact.
 */
.dash-background {
  background: transparent !important;
  background-color: transparent !important;
}

/* ── Dock background pill — neon border + outer glow ────────────────────────
 *
 * Use the plain .dash-background class selector (not a descendant chain)
 * so GNOME Shell's CSS engine always matches it regardless of actor hierarchy.
 *
 * !important is required on border and box-shadow because Dash to Dock's
 * theming.js calls set_style('border-color:...') as an inline style when
 * custom-background-color=true, which would otherwise override the border.
 * Open Bar also injects dock border CSS with !important; both target the
 * same colour (from bcolor/the accent), so they reinforce each other.
 */
.dash-background {
  border: 1.5px solid rgba(${r}, ${g}, ${b}, 0.65) !important;
  box-shadow:
    0 0  6px rgba(${r}, ${g}, ${b}, 0.55),
    0 0 14px rgba(${r}, ${g}, ${b}, 0.30),
    0 0 24px rgba(${r}, ${g}, ${b}, 0.12) !important;
  border-radius: 14px !important;
}
CSS
}

# Apply Catppuccin GTK theme, icon theme, and cursor theme to all Flatpak sandboxes.
# Requires FLAVOR, ACCENT_LOWER, GTK_THEME_NAME locals (set by apply_catppuccin_theme).
_apply_flatpak_theming() {
  if ! command_exists flatpak; then
    return
  fi

  log "Applying Catppuccin theme to Flatpak apps"

  local cursor_name="catppuccin-${FLAVOR}-${ACCENT_LOWER}-cursors"

  # Grant read access to the directories where our themes/icons/cursors live
  sudo flatpak override --filesystem="$HOME/.themes:ro"
  sudo flatpak override --filesystem="$HOME/.icons:ro"
  sudo flatpak override --filesystem=/usr/share/icons/Papirus-Dark:ro

  # Push GTK theme, icon theme, and cursor theme into every sandbox
  sudo flatpak override --env=GTK_THEME="${GTK_THEME_NAME}"
  sudo flatpak override --env=ICON_THEME=Papirus-Dark
  sudo flatpak override --env=XCURSOR_THEME="${cursor_name}"
}

# Write a Burn My Windows profile using the glitch effect (fits the neon aesthetic)
# and point dconf to it so it activates on next login.
_create_burn_my_windows_profile() {
  local profile_dir="$HOME/.config/burn-my-windows/profiles"
  local profile_path="$profile_dir/catppuccin-neon.conf"

  log "Writing Burn My Windows profile (glitch effect)"
  mkdir -p "$profile_dir"

  cat > "$profile_path" <<'CONF'
[burn-my-windows-profile]
profile-highrpix-effect=false
profile-window-effect=glitch
profile-animation-time=400
glitch-scale=1.0
glitch-speed=1.5
CONF

  if command_exists gsettings; then
    gsettings set org.gnome.shell.extensions.burn-my-windows \
      active-profile "${profile_path}" 2>/dev/null || true
  fi
}

apply_gnome_defaults() {
  if ! command_exists gsettings; then
    return
  fi

  log "Applying GNOME default applications and input settings"

  # Default terminal: Kitty
  if command_exists kitty; then
    # GNOME Terminal settings-daemon key (used by keyboard shortcut and file manager)
    gsettings set org.gnome.desktop.default-applications.terminal exec 'kitty'
    gsettings set org.gnome.desktop.default-applications.terminal exec-arg ''

    # xdg-terminal-exec preference file (used by many modern apps)
    local xdg_terminal_dir="$HOME/.config"
    mkdir -p "$xdg_terminal_dir"
    printf '[Default Terminal]\nExec=kitty\n' > "$xdg_terminal_dir/xdg-terminals.list"

    # Update xdg mime default for x-terminal-emulator
    if command_exists xdg-mime; then
      xdg-mime default kitty.desktop x-scheme-handler/terminal 2>/dev/null || true
    fi

    # GNOME's own terminal handler used by Nautilus "Open Terminal"
    if command_exists update-alternatives; then
      sudo update-alternatives --set x-terminal-emulator "$(command -v kitty)" 2>/dev/null || true
    fi
  fi

  # Keyboard: faster repeat rate (useful for vim navigation)
  gsettings set org.gnome.desktop.peripherals.keyboard repeat-interval 20
  gsettings set org.gnome.desktop.peripherals.keyboard delay 250
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
  install_monaspace_nerd_font
  install_papirus_icon_theme
  install_papirus_folders
  install_zoxide
  install_delta
  apply_catppuccin_theme
  apply_gnome_defaults
  set_user_avatar
  bash "$SCRIPT_DIR/tidal/install-ncmpcpp-tidal.sh"
  remove_legacy_nvim_cron

  log "Setup complete. Run '$SCRIPT_DIR/install' to apply dotfiles."
}

main "$@"
