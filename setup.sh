#!/usr/bin/env bash
# setup.sh — KDE Plasma 6 · Catppuccin Mocha · Debian 13 · Wayland
# Run as your normal user (sudo available). Idempotent — safe to re-run.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo -e "\033[1;34m==>\033[0m $*"; }
ok()    { echo -e "\033[1;32m OK\033[0m $*"; }
warn()  { echo -e "\033[1;33mWRN\033[0m $*"; }
skip()  { echo -e "\033[1;36mSKP\033[0m $* (already installed)"; }

# Clone to a fixed /tmp path, wiping any previous partial clone.
clone_fresh() { rm -rf "$1"; git clone --depth=1 "$2" "$1"; }

# ---------------------------------------------------------------------------
# Phase 1 — APT base packages
# ---------------------------------------------------------------------------
info "Phase 1 · APT base packages"

sudo apt update -y
sudo apt upgrade -y
sudo apt install -y \
  git curl wget unzip \
  zsh vim \
  build-essential cmake ninja-build \
  clangd g++ pkg-config \
  python3-pip python3-venv \
  wl-clipboard \
  xdg-utils \
  qt6-style-kvantum \
  papirus-icon-theme \
  kitty \
  fzf zoxide \
  imagemagick doxygen \
  fastfetch \
  plasma-systemmonitor

ok "APT base packages installed"

# ---------------------------------------------------------------------------
# Phase 1b — Node.js LTS (needed for Neovim LSP tools)
# ---------------------------------------------------------------------------
info "Phase 1b · Node.js LTS"

if command -v node &>/dev/null; then
  skip "Node.js ($(node --version))"
else
  NODE_SETUP="$(mktemp)"
  curl -fsSL https://deb.nodesource.com/setup_lts.x -o "$NODE_SETUP"
  sudo bash "$NODE_SETUP"
  rm "$NODE_SETUP"
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  ok "Node.js LTS installed ($(node --version))"
fi

# ---------------------------------------------------------------------------
# Phase 1c — Neovim (latest stable prebuilt) + LSP tools
# ---------------------------------------------------------------------------
info "Phase 1c · Neovim + LSP"

NVIM_API=$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest)
NVIM_TAG=$(echo "$NVIM_API" | grep -m1 '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

NVIM_CURRENT=$(nvim --version 2>/dev/null | grep -oP '(?<=NVIM )v[\d.]+' | head -1 || true)
if [[ "$NVIM_CURRENT" == "$NVIM_TAG" ]]; then
  skip "Neovim ${NVIM_TAG}"
else
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64)  NVIM_ARCH="x86_64" ;;
    aarch64) NVIM_ARCH="arm64"  ;;
    *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
  esac

  NVIM_TMP="$(mktemp -d)"
  curl -fL "https://github.com/neovim/neovim/releases/download/${NVIM_TAG}/nvim-linux-${NVIM_ARCH}.tar.gz" \
    -o "$NVIM_TMP/nvim.tar.gz"
  tar -xzf "$NVIM_TMP/nvim.tar.gz" -C "$NVIM_TMP"
  NVIM_DIR="$(find "$NVIM_TMP" -maxdepth 1 -type d -name 'nvim-linux-*' | head -1)"
  sudo rm -rf /opt/nvim
  sudo mv "$NVIM_DIR" /opt/nvim
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$NVIM_TMP"
  ok "Neovim ${NVIM_TAG} installed"
fi

sudo npm install -g typescript typescript-language-server bash-language-server pyright
ok "LSP tools up-to-date"

# ---------------------------------------------------------------------------
# Phase 1d — Modern CLI tools
# ---------------------------------------------------------------------------
info "Phase 1d · Modern CLI tools"

# Tools available in Debian apt (binary names differ from upstream on Debian)
sudo apt install -y \
  bat \
  fd-find \
  ripgrep \
  btop \
  duf \
  jq

# Helper: fetch latest GitHub release tag without SIGPIPE from grep -m1
# Uses python3 to consume the full JSON (avoids curl: (23) under pipefail)
gh_latest_tag() { curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])"; }

# eza — install via official apt repo (asset names vary across releases)
if ! command -v eza &>/dev/null; then
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  sudo apt update -y
  sudo apt install -y eza
  ok "eza installed"
else
  skip "eza ($(eza --version 2>/dev/null | head -1))"
fi

# dust (du replacement) — grab latest tarball from GitHub
if ! command -v dust &>/dev/null; then
  DUST_TAG=$(gh_latest_tag bootandy/dust)
  DUST_TGZ="dust-${DUST_TAG}-x86_64-unknown-linux-musl.tar.gz"
  curl -fLo "/tmp/dust.tar.gz" \
    "https://github.com/bootandy/dust/releases/download/${DUST_TAG}/${DUST_TGZ}"
  tar -xzf /tmp/dust.tar.gz -C /tmp/
  sudo mv "/tmp/dust-${DUST_TAG}-x86_64-unknown-linux-musl/dust" /usr/local/bin/dust
  sudo chmod +x /usr/local/bin/dust
  rm -rf /tmp/dust.tar.gz "/tmp/dust-${DUST_TAG}-x86_64-unknown-linux-musl"
  ok "dust ${DUST_TAG} installed"
else
  skip "dust"
fi

# delta (git diff pager) — grab latest .deb from GitHub
if ! command -v delta &>/dev/null; then
  DELTA_TAG=$(gh_latest_tag dandavison/delta)
  DELTA_DEB="git-delta_${DELTA_TAG}_amd64.deb"
  curl -fLo "/tmp/$DELTA_DEB" \
    "https://github.com/dandavison/delta/releases/download/${DELTA_TAG}/${DELTA_DEB}"
  sudo dpkg -i "/tmp/$DELTA_DEB"
  rm "/tmp/$DELTA_DEB"
  ok "delta ${DELTA_TAG} installed"
else
  skip "delta"
fi

# Wire delta into git as the diff/pager
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global delta.dark true
git config --global delta.syntax-theme "Catppuccin Mocha"

ok "Modern CLI tools installed"

# ---------------------------------------------------------------------------
# Phase 2 — Fonts
# ---------------------------------------------------------------------------
info "Phase 2 · Fonts"

# Inter (UI font) — in APT
sudo apt install -y fonts-inter-variable

# JetBrains Mono Nerd Font — manual (Nerd variant not in APT)
JBMONO_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerd"
if ls "$JBMONO_DIR"/*.ttf &>/dev/null 2>&1; then
  skip "JetBrains Mono Nerd Font"
else
  NERD_VERSION=$(curl -s 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' \
    | grep -Po '"tag_name": "\K[^"]*')
  curl -fLo /tmp/JetBrainsMono.zip \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_VERSION}/JetBrainsMono.zip"
  mkdir -p "$JBMONO_DIR"
  unzip -o /tmp/JetBrainsMono.zip -d "$JBMONO_DIR"
  rm /tmp/JetBrainsMono.zip
  fc-cache -fv
  ok "JetBrains Mono Nerd Font ${NERD_VERSION} installed"
fi

# ---------------------------------------------------------------------------
# Phase 3 — catppuccin/kde (global theme, colors, decorations, cursors)
# ---------------------------------------------------------------------------
info "Phase 3 · catppuccin/kde"

clone_fresh /tmp/catppuccin-kde https://github.com/catppuccin/kde
cd /tmp/catppuccin-kde
# Args: Mocha=1, Mauve=4, Modern decorations=1
# printf answers the two confirmation prompts without broken-pipe from 'yes'
printf 'y\ny\n' | ./install.sh 1 4 1
cd "$REPO_DIR"
rm -rf /tmp/catppuccin-kde

plasma-apply-colorscheme CatppuccinMochaMauve
plasma-apply-lookandfeel --apply Catppuccin-Mocha-Mauve
ok "catppuccin/kde applied"

# ---------------------------------------------------------------------------
# Phase 4 — Kvantum Qt app style
# ---------------------------------------------------------------------------
info "Phase 4 · Kvantum"

clone_fresh /tmp/catppuccin-kvantum https://github.com/catppuccin/kvantum.git
mkdir -p ~/.config/Kvantum
cp -r /tmp/catppuccin-kvantum/themes/catppuccin-mocha-mauve ~/.config/Kvantum/
rm -rf /tmp/catppuccin-kvantum

kvantummanager --set catppuccin-mocha-mauve
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
ok "Kvantum configured"

# ---------------------------------------------------------------------------
# Phase 5 — GTK bridge (catppuccin/gtk for non-Qt apps)
# ---------------------------------------------------------------------------
info "Phase 5 · GTK bridge"

curl -LsSo /tmp/catppuccin-gtk-install.py \
  "https://raw.githubusercontent.com/catppuccin/gtk/v1.0.3/install.py"
# Wipe gtk-4.0 dir to avoid FileExistsError for any pre-existing symlinks/files
rm -rf ~/.config/gtk-4.0
python3 /tmp/catppuccin-gtk-install.py mocha mauve --link
rm /tmp/catppuccin-gtk-install.py

# Flatpak filesystem access for GTK theming
if command -v flatpak &>/dev/null; then
  sudo flatpak override --filesystem=xdg-config/gtk-3.0:ro
  sudo flatpak override --filesystem=xdg-config/gtk-4.0:ro
  sudo flatpak override --filesystem=~/.themes:ro
  sudo flatpak override --filesystem=~/.icons:ro
  sudo flatpak override --env=GTK_THEME=catppuccin-mocha-mauve-standard+default
fi
ok "GTK bridge configured"

# ---------------------------------------------------------------------------
# Phase 6 — Icons (Papirus-Dark + catppuccin/papirus-folders)
# ---------------------------------------------------------------------------
info "Phase 6 · Icons"

clone_fresh /tmp/catppuccin-papirus https://github.com/catppuccin/papirus-folders.git
sudo cp -r /tmp/catppuccin-papirus/src/* /usr/share/icons/Papirus/
rm -rf /tmp/catppuccin-papirus

curl -fLo /tmp/papirus-folders \
  "https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders"
chmod +x /tmp/papirus-folders
/tmp/papirus-folders -C cat-mocha-mauve --theme Papirus-Dark
rm /tmp/papirus-folders
ok "Papirus-Dark + cat-mocha-mauve folders configured"

# Papirus-Dark is the system-wide icon theme (full KDE + hicolor coverage).
# catppuccin-vibes is NOT a full theme — it's 15 SVGs used only as custom
# icons for pinned dock launchers (see .desktop overrides below).
kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark
ok "Icons configured (Papirus-Dark + cat-mocha-mauve folders)"

# catppuccin-vibes dock icons — download SVGs and create .desktop overrides
# so the four pinned launchers show catppuccin-styled icons in the dock.
VIBES_DIR="$HOME/.local/share/icons/catppuccin-vibes"
mkdir -p "$VIBES_DIR"
VIBES_BASE="https://raw.githubusercontent.com/generalentropy/catppuccin-vibes/main/icons/catppuccin-vibrant"
for _icon in apps-vibrant terminal-vibrant folder-vibrant browser-vibrant music-vibrant; do
  curl -fLo "$VIBES_DIR/${_icon}.svg" "${VIBES_BASE}/${_icon}.svg"
done
ok "catppuccin-vibes SVGs downloaded to $VIBES_DIR"

# .desktop overrides — freedesktop spec: ~/.local/share/applications/ takes
# precedence over /usr/share/applications/ for icon resolution in icontasks.
LOCAL_APPS="$HOME/.local/share/applications"
mkdir -p "$LOCAL_APPS"

# Kitty
if [[ -f /usr/share/applications/kitty.desktop ]]; then
  cp /usr/share/applications/kitty.desktop "$LOCAL_APPS/kitty.desktop"
  sed -i "s|^Icon=.*|Icon=$VIBES_DIR/terminal-vibrant.svg|" "$LOCAL_APPS/kitty.desktop"
fi

# Dolphin
if [[ -f /usr/share/applications/org.kde.dolphin.desktop ]]; then
  cp /usr/share/applications/org.kde.dolphin.desktop "$LOCAL_APPS/org.kde.dolphin.desktop"
  sed -i "s|^Icon=.*|Icon=$VIBES_DIR/folder-vibrant.svg|" "$LOCAL_APPS/org.kde.dolphin.desktop"
fi

# Firefox — Debian ships firefox-esr.desktop; override whichever is present
for _ff in firefox.desktop firefox-esr.desktop; do
  if [[ -f /usr/share/applications/$_ff ]]; then
    cp /usr/share/applications/$_ff "$LOCAL_APPS/$_ff"
    sed -i "s|^Icon=.*|Icon=$VIBES_DIR/browser-vibrant.svg|" "$LOCAL_APPS/$_ff"
  fi
done
ok "catppuccin-vibes .desktop overrides created for Kitty / Dolphin / Firefox"

# ---------------------------------------------------------------------------
# Phase 6b - Firefox theme (Catppuccin Mocha Mauve)
# ---------------------------------------------------------------------------
info "Phase 6b · Firefox theme"

FIREFOX_THEME_URL="https://github.com/catppuccin/firefox/releases/download/old/catppuccin_mocha_mauve.xpi"
FIREFOX_THEME_ID="{76aabc99-c1a8-4c1e-832b-d4f2941d5a7a}"
FIREFOX_THEME_TMP="$(mktemp --suffix=.xpi)"
FIREFOX_THEME_INSTALLED=0

if curl -fsSL -o "$FIREFOX_THEME_TMP" "$FIREFOX_THEME_URL"; then
  for _ff_root in /usr/lib/firefox /usr/lib/firefox-esr; do
    if [[ -d "$_ff_root" ]]; then
      sudo mkdir -p "$_ff_root/distribution/extensions"
      sudo install -m 0644 "$FIREFOX_THEME_TMP" \
        "$_ff_root/distribution/extensions/${FIREFOX_THEME_ID}.xpi"
      FIREFOX_THEME_INSTALLED=1
    fi
  done
  rm -f "$FIREFOX_THEME_TMP"

  if [[ "$FIREFOX_THEME_INSTALLED" -eq 1 ]]; then
    ok "Catppuccin Mocha Mauve Firefox theme installed"
    warn "Manual step: if Firefox keeps the default look, open Add-ons and Themes and select 'Catppuccin Mocha - Mauve'."
  else
    warn "Firefox not found under /usr/lib/firefox or /usr/lib/firefox-esr; skipped theme install."
  fi
else
  rm -f "$FIREFOX_THEME_TMP"
  warn "Could not download Catppuccin Firefox theme; skipped."
fi

# ---------------------------------------------------------------------------
# Phase 7 — KWin blur
# ---------------------------------------------------------------------------
info "Phase 7 · KWin blur"

# Stock KWin blur is DISABLED — kwin-better-blur (Phase 7b) replaces it.
# Better-blur can blur any semi-transparent window; the stock effect cannot.
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file kwinrc --group Plugins --key backgroundcontrastEnabled true

kwriteconfig6 --file kwinrc --group Plugins --key roundedcornersEnabled true
kwriteconfig6 --file kwinrc --group Effect-roundedcorners --key Radius 12

# Dolphin window rule — force 88 % opacity so kwin-better-blur can blur behind it.
# Plasma 6 uses the "rule" suffix (not "settings") for policy values; 2 = Force.
# wmclassmatch=2 = substring match (safer than exact on Wayland).
if ! grep -q "dolphin" "$HOME/.config/kwinrulesrc" 2>/dev/null; then
  kwriteconfig6 --file kwinrulesrc --group General --key count 1
  kwriteconfig6 --file kwinrulesrc --group 1 --key Description "Dolphin — transparency + blur"
  kwriteconfig6 --file kwinrulesrc --group 1 --key wmclass "dolphin"
  kwriteconfig6 --file kwinrulesrc --group 1 --key wmclasscomplete false
  kwriteconfig6 --file kwinrulesrc --group 1 --key wmclassmatch 2
  kwriteconfig6 --file kwinrulesrc --group 1 --key opacityactive 90
  kwriteconfig6 --file kwinrulesrc --group 1 --key opacityactiverule 2
  kwriteconfig6 --file kwinrulesrc --group 1 --key opacityinactive 88
  kwriteconfig6 --file kwinrulesrc --group 1 --key opacityinactiverule 2
fi
ok "KWin blur + rounded corners + Dolphin opacity rule written"

# ---------------------------------------------------------------------------
# Phase 7b — kwin-better-blur (force blur behind any semi-transparent window)
# ---------------------------------------------------------------------------
info "Phase 7b · kwin-better-blur"

# Build dependencies — kwin-dev alone is not enough; list missing KF6 components
# explicitly. Package names mirror the CMake find_package component names.
sudo apt install -y \
  kwin-dev extra-cmake-modules \
  libkf6configwidgets-dev \
  libkf6crash-dev \
  libkf6globalaccel-dev \
  libkf6i18n-dev \
  libkf6kio-dev \
  libkf6service-dev \
  libkf6notifications-dev \
  libkf6widgetsaddons-dev \
  libkf6guiaddons-dev \
  libkf6kcmutils-dev \
  libxkbcommon-dev \
  libkdecorations3-dev \
  libxcb-composite0-dev \
  libxcb-randr0-dev \
  libxcb-shm0-dev

BETTERBLUR_BUILD="$(mktemp -d)"
# Pin to v1.3.6 — last release that supports Plasma < 6.4.
# v1.4.0+ added a hard "minimum Plasma 6.4" guard; Debian 13 ships 6.3.x.
rm -rf /tmp/kwin-better-blur
git clone --depth=1 --branch v1.3.6 \
  https://github.com/taj-ny/kwin-effects-forceblur.git /tmp/kwin-better-blur
cmake -S /tmp/kwin-better-blur -B "$BETTERBLUR_BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr
cmake --build "$BETTERBLUR_BUILD" -j"$(nproc)"
sudo cmake --install "$BETTERBLUR_BUILD"
rm -rf /tmp/kwin-better-blur "$BETTERBLUR_BUILD"

# Enable the effect — plugin ID is derived from CMakeLists project name
kwriteconfig6 --file kwinrc --group Plugins --key kwin_better_blurEnabled true
ok "kwin-better-blur installed and enabled"
warn "Manual step: System Settings → Desktop Effects → Better Blur → Configure → set 'Blur all windows' and adjust blur strength (try 10-15)."

# ---------------------------------------------------------------------------
# Phase 8 — Krohnkite tiling script
# ---------------------------------------------------------------------------
info "Phase 8 · Krohnkite tiling"

# The plain krohnkite.kwinscript asset has a persistent 500 bug on GitHub.
# Use the API to get the versioned asset URL instead.
KROHNKITE_URL=$(curl -fsSL https://api.github.com/repos/anametologin/krohnkite/releases/latest \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
assets = [a for a in data['assets'] if a['name'].endswith('.kwinscript')]
versioned = [a for a in assets if a['name'] != 'krohnkite.kwinscript']
print((versioned or assets)[0]['browser_download_url'])
")
wget -O /tmp/krohnkite.kwinscript "$KROHNKITE_URL"
kpackagetool6 --type=KWin/Script -i /tmp/krohnkite.kwinscript 2>/dev/null \
  || kpackagetool6 --type=KWin/Script -u /tmp/krohnkite.kwinscript
rm /tmp/krohnkite.kwinscript

kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled true

# Gap between tiled windows and screen edges (px).
# Keys are camelCase — Krohnkite reads them via KWin.readConfig().
# screenGapBetween = gap between adjacent tiles (NOT tileLayoutGap — that key
# does not exist in the anametologin fork).
kwriteconfig6 --file kwinrc --group Script-krohnkite --key screenGapBetween 8
kwriteconfig6 --file kwinrc --group Script-krohnkite --key screenGapTop     8
kwriteconfig6 --file kwinrc --group Script-krohnkite --key screenGapBottom  8
kwriteconfig6 --file kwinrc --group Script-krohnkite --key screenGapLeft    8
kwriteconfig6 --file kwinrc --group Script-krohnkite --key screenGapRight   8
ok "Krohnkite installed and enabled (8 px gaps)"

# ---------------------------------------------------------------------------
# Phase 9 — Dock + Wallpaper (registered as autostart; needs live plasmashell)
# ---------------------------------------------------------------------------
info "Phase 9 · Dock + Wallpaper autostart"

# configure-dock.sh and plasma-apply-wallpaperimage both require D-Bus to a
# running plasmashell — they cannot run headlessly during setup.sh.
# Register a one-shot autostart that fires on the first KDE login instead.
chmod +x "$REPO_DIR/scripts/setup-first-login.sh"
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/kde-post-install.desktop" << EOF
[Desktop Entry]
Type=Application
Name=KDE Post-Install Setup
Comment=One-time: configure dock panels and wallpaper (requires live Plasma session)
Exec=/bin/bash "$REPO_DIR/scripts/setup-first-login.sh"
Terminal=false
X-KDE-AutostartScript=true
EOF
ok "Autostart registered — panels and wallpaper configured on next login"

# ---------------------------------------------------------------------------
# Phase 9b — Panel Colorizer (pill-style widget islands for the top bar)
# ---------------------------------------------------------------------------
info "Phase 9b · Panel Colorizer"

PC_VERSION="6.8.1"
PC_TMP="$(mktemp --suffix=.plasmoid)"
curl -fsSL -o "$PC_TMP" \
  "https://github.com/luisbocanegra/plasma-panel-colorizer/releases/download/v${PC_VERSION}/plasmoid-panel-colorizer-v${PC_VERSION}.plasmoid"
kpackagetool6 --type Plasma/Applet --install "$PC_TMP" 2>/dev/null \
  || kpackagetool6 --type Plasma/Applet --upgrade "$PC_TMP"
rm -f "$PC_TMP"
ok "Panel Colorizer ${PC_VERSION} installed"

# ---------------------------------------------------------------------------
# Phase 10 — Kitty terminal config
# ---------------------------------------------------------------------------
info "Phase 10 · Kitty config"

mkdir -p ~/.config/kitty
ok "Kitty config directory ready (dotbot will link kitty/kitty.conf)"

# ---------------------------------------------------------------------------
# Phase 11 — Zsh + oh-my-zsh + Starship
# ---------------------------------------------------------------------------
info "Phase 11 · Zsh + oh-my-zsh + Starship"

# Change shell to zsh
[[ "$(getent passwd "$USER" | cut -d: -f7)" != "/bin/zsh" ]] && chsh -s /bin/zsh

# oh-my-zsh (non-interactive)
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Plugins
OMZ_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
[[ -d "$OMZ_CUSTOM/zsh-syntax-highlighting" ]] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$OMZ_CUSTOM/zsh-syntax-highlighting"
[[ -d "$OMZ_CUSTOM/zsh-autosuggestions" ]] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
    "$OMZ_CUSTOM/zsh-autosuggestions"
[[ -d "$OMZ_CUSTOM/zsh-history-substring-search" ]] || \
  git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search.git \
    "$OMZ_CUSTOM/zsh-history-substring-search"

# Starship
curl -fsSL https://starship.rs/install.sh | sh -s -- --yes

ok "Zsh + oh-my-zsh + Starship configured"

# Default terminal emulator — KDE defaults to Konsole; override with Kitty
kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop
ok "Default terminal set to Kitty"

# ---------------------------------------------------------------------------
# Phase 11b — Tidal (tidal-hifi via Flatpak)
# ---------------------------------------------------------------------------
info "Phase 11b · Tidal (tidal-hifi)"

if ! command -v flatpak &>/dev/null; then
  sudo apt install -y flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

if ! flatpak list --app | grep -q "com.mastermindzh.tidal-hifi"; then
  flatpak install -y flathub com.mastermindzh.tidal-hifi
  ok "tidal-hifi installed"
else
  skip "tidal-hifi"
fi

# Wayland flags — .desktop override so launcher uses native Wayland rendering
TIDAL_DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$TIDAL_DESKTOP_DIR"
cat > "$TIDAL_DESKTOP_DIR/com.mastermindzh.tidal-hifi.desktop" << 'EOF'
[Desktop Entry]
Name=TIDAL Hi-Fi
Comment=Tidal music streaming (Catppuccin Mocha)
Exec=flatpak run com.mastermindzh.tidal-hifi -- --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations,WaylandLinuxDmabuf --enable-wayland-ime
Icon=com.mastermindzh.tidal-hifi
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Music;Player;
StartupWMClass=tidal-hifi
EOF
# Patch icon to catppuccin-vibes music SVG (Phase 6 downloads it)
VIBES_MUSIC="$HOME/.local/share/icons/catppuccin-vibes/music-vibrant.svg"
[[ -f "$VIBES_MUSIC" ]] && \
  sed -i "s|^Icon=.*|Icon=$VIBES_MUSIC|" "$TIDAL_DESKTOP_DIR/com.mastermindzh.tidal-hifi.desktop"
ok "tidal-hifi .desktop override written (Wayland flags)"

# Catppuccin Mocha CSS theme for tidal-hifi
# Load via: tidal-hifi → Settings → Theming → choose this file
TIDAL_THEME_DIR="$HOME/.config/tidal-hifi"
mkdir -p "$TIDAL_THEME_DIR"
cat > "$TIDAL_THEME_DIR/catppuccin-mocha.css" << 'ENDCSS'
/* Catppuccin Mocha theme for tidal-hifi
   Load via: Settings > Theming > "Choose theme file"
   Palette: Base #1e1e2e  Mantle #181825  Crust #11111b
            Surface0 #313244  Text #cdd6f4  Mauve #cba6f7 */
:root {
  --ctp-base:    #1e1e2e;
  --ctp-mantle:  #181825;
  --ctp-crust:   #11111b;
  --ctp-surface0:#313244;
  --ctp-surface1:#45475a;
  --ctp-text:    #cdd6f4;
  --ctp-subtext0:#a6adc8;
  --ctp-mauve:   #cba6f7;
  --ctp-peach:   #fab387;
  --ctp-green:   #a6e3a1;
  --ctp-red:     #f38ba8;
  --ctp-blue:    #89b4fa;
}
#react-root, body, .nowPlaying, .mainContent, .main-content {
  background-color: var(--ctp-base) !important;
  color: var(--ctp-text) !important;
}
nav, [class*="sidebar"], [class*="NavigationMenu"] {
  background-color: var(--ctp-mantle) !important;
}
[class*="playbackControls"], [class*="footer"], #footerPlayer {
  background-color: var(--ctp-crust) !important;
  border-top: 1px solid var(--ctp-surface0) !important;
}
[class*="progressBar"] [role="progressbar"],
[class*="progressBar"] [class*="bar"] {
  background-color: var(--ctp-mauve) !important;
}
button[class*="playButton"], [class*="button--primary"] {
  background-color: var(--ctp-mauve) !important;
  color: var(--ctp-base) !important;
}
a, [class*="title"], [class*="trackName"] {
  color: var(--ctp-text) !important;
}
a:hover { color: var(--ctp-mauve) !important; }
[class*="isPlaying"], [class*="active"] { color: var(--ctp-mauve) !important; }
[class*="card"], [class*="modal"], [class*="dialog"], [class*="dropdown"] {
  background-color: var(--ctp-surface0) !important;
  border: 1px solid var(--ctp-surface1) !important;
}
input, [class*="search"] {
  background-color: var(--ctp-surface0) !important;
  color: var(--ctp-text) !important;
  border-color: var(--ctp-surface1) !important;
}
::-webkit-scrollbar { width: 6px; }
::-webkit-scrollbar-track { background: var(--ctp-mantle); }
::-webkit-scrollbar-thumb { background: var(--ctp-surface1); border-radius: 3px; }
::-webkit-scrollbar-thumb:hover { background: var(--ctp-mauve); }
ENDCSS
ok "Catppuccin Mocha CSS theme written to ~/.config/tidal-hifi/catppuccin-mocha.css"
warn "Manual step: Open tidal-hifi → Settings → Theming → choose ~/.config/tidal-hifi/catppuccin-mocha.css"

# ---------------------------------------------------------------------------
# Phase 12 — SDDM (Catppuccin Mocha Mauve theme)
# ---------------------------------------------------------------------------
info "Phase 12 · SDDM"

sudo apt install -y --no-install-recommends \
  qml-module-qtquick-layouts \
  qml-module-qtquick-controls2 \
  libqt6svg6

cd /tmp
curl -LOsS https://github.com/catppuccin/sddm/releases/latest/download/catppuccin-mocha-mauve-sddm.zip
unzip -o catppuccin-mocha-mauve-sddm.zip
sudo rm -rf /usr/share/sddm/themes/catppuccin-mocha-mauve
sudo mv catppuccin-mocha-mauve /usr/share/sddm/themes/
rm catppuccin-mocha-mauve-sddm.zip

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-catppuccin.conf > /dev/null << 'EOF'
[Theme]
Current=catppuccin-mocha-mauve
EOF

# Set evening-sky.png as SDDM background via theme.conf.user (no theme edit needed)
sudo mkdir -p /usr/share/sddm/themes/catppuccin-mocha-mauve/backgrounds
sudo cp "$REPO_DIR/images/evening-sky.png" \
  /usr/share/sddm/themes/catppuccin-mocha-mauve/backgrounds/evening-sky.png
sudo tee /usr/share/sddm/themes/catppuccin-mocha-mauve/theme.conf.user > /dev/null << 'EOF'
[General]
CustomBackground=true
Background="backgrounds/evening-sky.png"
EOF

cd "$REPO_DIR"
ok "SDDM theme installed (catppuccin-mocha-mauve) with evening-sky.png background"

# ---------------------------------------------------------------------------
# Phase 13 — GRUB (catppuccin/grub)
# ---------------------------------------------------------------------------
info "Phase 13 · GRUB"

clone_fresh /tmp/catppuccin-grub https://github.com/catppuccin/grub.git
sudo rm -rf /usr/share/grub/themes/catppuccin-mocha-grub-theme
sudo cp -r /tmp/catppuccin-grub/src/catppuccin-mocha-grub-theme /usr/share/grub/themes/
rm -rf /tmp/catppuccin-grub

GRUB_FILE=/etc/default/grub
sudo sed -i 's|^#\?GRUB_THEME=.*|GRUB_THEME="/usr/share/grub/themes/catppuccin-mocha-grub-theme/theme.txt"|' "$GRUB_FILE"
sudo sed -i 's|^#\?GRUB_GFXMODE=.*|GRUB_GFXMODE=1920x1080|' "$GRUB_FILE"
sudo update-grub
ok "GRUB theme applied"

# ---------------------------------------------------------------------------
# Phase 14 — Dotfiles (dotbot)
# ---------------------------------------------------------------------------
info "Phase 14 · Dotfiles (dotbot)"

"$REPO_DIR/install"
ok "Base dotfiles linked (zshrc, zshenv, kitty, starship, gitconfig, kvantum, gtk, envvars)"

# Desktop wallpaper — applied by setup-first-login.sh on first login (needs plasmashell)

# Lock screen wallpaper (kwriteconfig6 works without a session)
kwriteconfig6 --file kscreenlockerrc \
  --group Greeter --group Wallpaper --group "org.kde.image" --group General \
  --key Image "file://$REPO_DIR/images/evening-sky.png"
ok "Lock screen wallpaper applied (evening-sky.png)"

warn "Run './install -c install-plasma.conf.yaml' to also link plasma/ configs (kwinrc, kdeglobals, kscreenlockerrc)."
warn "Skip this before major KDE upgrades."

# ---------------------------------------------------------------------------
# Post-install summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " KDE Plasma setup complete!"
echo "============================================================"
echo ""
echo " Automatic on next login (via autostart):"
echo "   · Dock + top bar panels will be created"
echo "   · Desktop wallpaper will be applied"
echo ""
echo " Manual steps remaining:"
echo "   1. Configure Krohnkite gaps/keybinds in System Settings → KWin Scripts"
echo "   2. Restart session to apply SDDM + all env vars"
echo "   3. Tidal: open tidal-hifi → Settings → Theming →"
echo "      choose ~/.config/tidal-hifi/catppuccin-mocha.css"
echo "   4. Firefox: Add-ons and Themes → select 'Catppuccin Mocha - Mauve' if needed"
echo ""
echo " Optional: link plasma configs after reviewing compatibility:"
echo "   ./install -c install-plasma.conf.yaml"
echo ""
echo " Apply KWin changes without logout:"
echo "   qdbus6 org.kde.KWin /KWin reconfigure"
echo ""
