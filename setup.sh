#!/usr/bin/env bash
# setup.sh — KDE Plasma 6 · Catppuccin Mocha · Debian 13 · Wayland
# Run as your normal user (sudo available). Not idempotent — intended for
# a fresh Debian 13 installation.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo -e "\033[1;34m==>\033[0m $*"; }
ok()    { echo -e "\033[1;32m OK\033[0m $*"; }
warn()  { echo -e "\033[1;33mWRN\033[0m $*"; }

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
  imagemagick doxygen

ok "APT base packages installed"

# ---------------------------------------------------------------------------
# Phase 2 — Fonts
# ---------------------------------------------------------------------------
info "Phase 2 · Fonts"

# Inter (UI font) — in APT
sudo apt install -y fonts-inter-variable

# JetBrains Mono Nerd Font — manual (Nerd variant not in APT)
NERD_VERSION=$(curl -s 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' \
  | grep -Po '"tag_name": "\K[^"]*')
curl -fLo /tmp/JetBrainsMono.zip \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_VERSION}/JetBrainsMono.zip"
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerd
unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts/JetBrainsMonoNerd
rm /tmp/JetBrainsMono.zip
fc-cache -fv
ok "Fonts installed (Inter + JetBrains Mono Nerd Font ${NERD_VERSION})"

# ---------------------------------------------------------------------------
# Phase 3 — catppuccin/kde (global theme, colors, decorations, cursors)
# ---------------------------------------------------------------------------
info "Phase 3 · catppuccin/kde"

git clone --depth=1 https://github.com/catppuccin/kde /tmp/catppuccin-kde
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

git clone --depth=1 https://github.com/catppuccin/kvantum.git /tmp/catppuccin-kvantum
mkdir -p ~/.config/Kvantum
cp -r /tmp/catppuccin-kvantum/themes/mocha/Catppuccin-Mocha-Mauve ~/.config/Kvantum/
rm -rf /tmp/catppuccin-kvantum

kvantummanager --set Catppuccin-Mocha-Mauve
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
ok "Kvantum configured"

# ---------------------------------------------------------------------------
# Phase 5 — GTK bridge (catppuccin/gtk for non-Qt apps)
# ---------------------------------------------------------------------------
info "Phase 5 · GTK bridge"

curl -LsSo /tmp/catppuccin-gtk-install.py \
  "https://raw.githubusercontent.com/catppuccin/gtk/v1.0.3/install.py"
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

git clone --depth=1 https://github.com/catppuccin/papirus-folders.git /tmp/catppuccin-papirus
sudo cp -r /tmp/catppuccin-papirus/src/* /usr/share/icons/Papirus/
rm -rf /tmp/catppuccin-papirus

curl -fLo /tmp/papirus-folders \
  "https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders"
chmod +x /tmp/papirus-folders
/tmp/papirus-folders -C cat-mocha-mauve --theme Papirus-Dark
rm /tmp/papirus-folders
ok "Icons configured (Papirus-Dark + cat-mocha-mauve folders)"

# ---------------------------------------------------------------------------
# Phase 7 — KWin blur
# ---------------------------------------------------------------------------
info "Phase 7 · KWin blur"

kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true
kwriteconfig6 --file kwinrc --group Plugins --key backgroundcontrastEnabled true
kwriteconfig6 --file kwinrc --group Effect-blur --key BlurStrength 9
kwriteconfig6 --file kwinrc --group Effect-blur --key NoiseStrength 2
ok "KWin blur enabled (strength=9, noise=2)"

# ---------------------------------------------------------------------------
# Phase 8 — Krohnkite tiling script
# ---------------------------------------------------------------------------
info "Phase 8 · Krohnkite tiling"

wget -O /tmp/krohnkite.kwinscript \
  "https://github.com/anametologin/krohnkite/releases/latest/download/krohnkite.kwinscript"
kpackagetool6 --type=KWin/Script -i /tmp/krohnkite.kwinscript
rm /tmp/krohnkite.kwinscript

kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled true
ok "Krohnkite installed and enabled"

# ---------------------------------------------------------------------------
# Phase 9 — Panel & widgets
# ---------------------------------------------------------------------------
info "Phase 9 · Panel & widgets"
warn "Panel layout must be configured manually in System Settings."
warn "Target: floating top panel, height 36px, translucent."
warn "Widgets (left→right): Kickoff | Window Title | Spacer | Sensor×2 | Media | Tray | Clock"

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
chsh -s /bin/zsh

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

# ---------------------------------------------------------------------------
# Phase 12 — SDDM (Catppuccin Mocha Mauve theme)
# ---------------------------------------------------------------------------
info "Phase 12 · SDDM"

sudo apt install -y --no-install-recommends \
  qml-module-qtquick-layouts \
  qml-module-qtquick-controls2 \
  libqt6svg6

cd /tmp
curl -LOsS https://github.com/catppuccin/sddm/releases/latest/download/catppuccin-mocha-mauve.zip
unzip -o catppuccin-mocha-mauve.zip
sudo mv catppuccin-mocha-mauve /usr/share/sddm/themes/
rm catppuccin-mocha-mauve.zip

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-catppuccin.conf > /dev/null << 'EOF'
[Theme]
Current=catppuccin-mocha-mauve
EOF

cd "$REPO_DIR"
ok "SDDM theme installed (catppuccin-mocha-mauve)"

# ---------------------------------------------------------------------------
# Phase 13 — GRUB (catppuccin/grub)
# ---------------------------------------------------------------------------
info "Phase 13 · GRUB"

git clone --depth=1 https://github.com/catppuccin/grub.git /tmp/catppuccin-grub
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
echo " Manual steps remaining:"
echo "   1. Configure panel in System Settings (see migration plan Phase 9)"
echo "   2. Set wallpaper: ~/Documents/Linux-Setup/images/evening-sky.png"
echo "   3. Configure Krohnkite gaps/keybinds in System Settings → KWin Scripts"
echo "   4. Restart session to apply SDDM + all env vars"
echo ""
echo " Optional: link plasma configs after reviewing compatibility:"
echo "   ./install -c install-plasma.conf.yaml"
echo ""
echo " Apply KWin changes without logout:"
echo "   qdbus org.kde.KWin /KWin reconfigure"
echo ""
