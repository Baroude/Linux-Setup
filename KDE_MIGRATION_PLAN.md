# KDE Plasma Migration Plan
## Catppuccin Mocha · Debian 13 · Wayland

Branch: `migration/kde-plasma`
Base: `main` (pre-GNOME migration)
Status: **Architecture locked — ready for implementation**

---

## Why KDE

| Reason | Detail |
|--------|--------|
| **Real window blur** | KWin implements the Wayland blur protocol. Kitty `background_blur` actually works. On GNOME/Mutter this is permanently impossible. |
| **Catppuccin/kde is the cleanest port** | One script installs: color scheme, Plasma theme, Aurorae decorations, splash, cursors. Actively maintained. The official `catppuccin/gtk` was archived June 2024. |
| **Extension count: 0–1 vs 7** | KDE needs 1 KWin script (tiling). GNOME needed 7 shell-injected extensions, each a breakage risk. |
| **SDDM > GDM** | `catppuccin/sddm` installs cleanly with a test mode. GDM theming requires recompiling a binary gresource. |
| **Shell restart without logout** | `systemctl --user restart plasma-plasmashell`. GNOME Wayland requires full session logout. |

---

## Target Stack

| Layer | Choice | Source |
|-------|--------|--------|
| OS | Debian 13 (Trixie) | APT |
| Desktop | KDE Plasma 6.3.6 | `task-kde-desktop` |
| Session | Wayland (default) | SDDM |
| Compositor | KWin 6 | Plasma |
| Terminal | Kitty | APT |
| Shell | Zsh + Starship | APT / upstream |
| Dotfiles | dotbot | git submodule |

---

## Build Timeline

| Phase | What | Notes |
|-------|------|-------|
| 1 | APT base packages | Core tools, build deps, fonts, wl-clipboard |
| 2 | Fonts | Nerd Font variant installed to `~/.local/share/fonts/` |
| 3 | catppuccin/kde | Global theme, colors, decorations, cursors — one script |
| 4 | Kvantum | Qt app style with translucent chrome |
| 5 | GTK bridge | For non-Qt apps |
| 6 | Icons | Papirus-Dark + catppuccin/papirus-folders |
| 7 | KWin blur | Enable blur + Background Contrast in Desktop Effects |
| 8 | Tiling script | See open decision §TILING |
| 9 | Panel & widgets | Configure floating top panel |
| 10 | Kitty | Full config with opacity + blur |
| 11 | Zsh + Starship | Shell config — see open decision §SHELL |
| 12 | SDDM | catppuccin/sddm theme |
| 13 | GRUB | catppuccin/grub (same as current approach) |
| 14 | Dotfiles | GNU Stow, dconf/kwriteconfig backup scripts |

---

## Theming Architecture

### Layer 1 — KDE / Qt (catppuccin/kde)

```bash
git clone --depth=1 https://github.com/catppuccin/kde catppuccin-kde
cd catppuccin-kde
./install.sh 1 4 1   # Mocha=1, Mauve=4, Modern decorations=1
```

Installs to `~/.local/share/`:
- `color-schemes/` — `.colors` files
- `plasma/desktoptheme/` — Plasma theme
- `aurorae/themes/` — window decorations
- `plasma/look-and-feel/` — global theme
- `~/.icons/` — cursors

Apply:
```bash
plasma-apply-colorscheme CatppuccinMochaMauve
plasma-apply-desktoptheme CatppuccinMochaMauve
```

### Layer 2 — Qt app chrome (Kvantum)

```bash
sudo apt install -y qt6-style-kvantum
git clone https://github.com/catppuccin/kvantum.git /tmp/catppuccin-kvantum
cp -r /tmp/catppuccin-kvantum/themes/mocha/Catppuccin-Mocha-Mauve ~/.config/Kvantum/
kvantummanager --set Catppuccin-Mocha-Mauve
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
```

Provides: translucent menus, tooltips with blur, fine-grained widget opacity.

### Layer 3 — GTK bridge (non-Qt apps)

```bash
# catppuccin/gtk v1.0.3 — --link creates gtk-4.0 symlinks for libadwaita
curl -LsSO "https://raw.githubusercontent.com/catppuccin/gtk/v1.0.3/install.py"
python3 install.py mocha mauve --link

# Flatpak access
sudo flatpak override --filesystem=xdg-config/gtk-3.0:ro
sudo flatpak override --filesystem=xdg-config/gtk-4.0:ro
sudo flatpak override --filesystem=~/.themes:ro
sudo flatpak override --filesystem=~/.icons:ro
sudo flatpak override --env=GTK_THEME=catppuccin-mocha-mauve-standard+default
```

### Layer 4 — Icons

```bash
# Already in APT: papirus-icon-theme
git clone https://github.com/catppuccin/papirus-folders.git /tmp/catppuccin-papirus
sudo cp -r /tmp/catppuccin-papirus/src/* /usr/share/icons/Papirus/

curl -LO https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders
chmod +x ./papirus-folders
./papirus-folders -C cat-mocha-mauve --theme Papirus-Dark   # ← accent TBD
```

---

## Blur Strategy

KWin blur works natively on Wayland. No extensions or hacks required.

```ini
# ~/.config/kwinrc
[Plugins]
blurEnabled=true

[Effect-blur]
BlurStrength=9      # Range 1–15. 9 = frosted glass without overdoing it.
NoiseStrength=2     # Prevents "cheap plastic" look of pure Gaussian blur.
```

Background Contrast (Plasma ≤6.4, separate from blur):
- Enable via: System Settings → Desktop Effects → Background Contrast

**Kitty terminal** — with KWin blur active:
```ini
background_opacity 0.90   # Readable on evening-sky.png; frosted glass via KWin blur
background_blur    64     # Requests blur from KWin via Wayland protocol. WORKS.
```

Apply without logout: `qdbus org.kde.KWin /KWin reconfigure`

---

## Window Tiling

> **OPEN DECISION** — see questions below.

### Option A: Krohnkite (recommended for auto-tiling)
- dwm-inspired dynamic tiling
- Supports GNOME 42–49, Wayland, Activities/virtual desktops
- Active fork: `anametologin/krohnkite`

```bash
wget https://github.com/anametologin/krohnkite/releases/latest/download/krohnkite.kwinscript
kpackagetool6 --type=KWin/Script -i krohnkite.kwinscript
```

Keybindings (vim-style):

| Action | Binding |
|--------|---------|
| Focus left/down/up/right | `Meta+H/J/K/L` |
| Move window | `Meta+Shift+H/J/K/L` |
| Grow/shrink master | `Meta+=` / `Meta+-` |
| Cycle layouts | `Meta+\` |
| Toggle float | `Meta+F` |
| Toggle tiling on/off | `Meta+T` |

Gaps: inner 8px, outer 8px.

Float exceptions: `systemsettings`, `krunner`, `plasmashell`, auth dialogs, all dialogs (default).

### Option B: KZones (FancyZones-style)
- JSON-defined snap zones with visual overlay
- Manual placement, no auto-tiling
- More stable (simpler codebase)

### Option C: Built-in KDE tiling (Meta+T)
- Ships with Plasma, zero risk
- Manual zone placement, no auto-tiling

Rollback for any option:
```bash
kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled false
qdbus org.kde.KWin /KWin reconfigure
```

---

## Panel Design

**Floating top panel, height 36px, translucent.**

| Position | Widget | Notes |
|----------|--------|-------|
| Left | Application Launcher (Kickoff) | Keyboard-searchable |
| Left | Window Title widget | Shows active window — valuable with tiling |
| Center | Flexible Spacer | |
| Right | System Monitor Sensor ×2 | Built-in: CPU%, RAM used |
| Right | Media Player | MPRIS, built-in |
| Right | System Tray | Network, volume, bluetooth only — hide rest |
| Right | Digital Clock | `ddd MMM d  HH:mm` |

**Workspace indicator:** KDE virtual desktops are configured via System Settings. No extension needed (unlike GNOME's Space Bar).

---

## Wayland Environment

`~/.config/plasma-workspace/env/envvars.sh` (sourced automatically on Plasma login):

```bash
# Qt apps: force Wayland (most already do on Plasma 6)
export QT_QPA_PLATFORM=wayland

# Electron/Chromium on Wayland
export ELECTRON_OZONE_PLATFORM_HINT=auto

# Java AWT fix
export _JAVA_AWT_WM_NONREPARENTING=1

# LibreOffice: Qt6 backend
export SAL_USE_VCLPLUGIN=qt6
```

**Do NOT set `GDK_BACKEND=wayland` globally** — breaks some GTK apps.

---

## Fonts

**Terminal/monospace:** JetBrains Mono Nerd Font (installed manually from Nerd Fonts releases)
**UI font:** Inter (`fonts-inter-variable` in APT)

```bash
# UI font — APT
sudo apt install -y fonts-inter-variable

# JetBrains Mono Nerd Font — manual (Nerd variant not in APT)
NERD_VERSION=$(curl -s 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' \
  | grep -Po '"tag_name": "\K[^"]*')
curl -fLo /tmp/JetBrainsMono.zip \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_VERSION}/JetBrainsMono.zip"
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerd
unzip /tmp/JetBrainsMono.zip -d ~/.local/share/fonts/JetBrainsMonoNerd
fc-cache -fv
fc-list | grep -i "JetBrains"
```

System Settings → Appearance → Fonts (configured via `gsettings` or `kwriteconfig6`):

| Setting | Font | Size |
|---------|------|------|
| General | Inter | 10pt |
| Fixed-width | JetBrainsMono Nerd Font | 10pt |
| Window title | Inter Bold | 10pt |
| Hinting | Slight | — |
| Anti-aliasing | Sub-pixel RGB | — |

---

## Shell Stack

**Framework:** oh-my-zsh (no change — terminal stack is DE-agnostic, avoiding scope creep)

The `zshrc` carries over from the GNOME setup with one addition — the missing zsh options
from the research reports are worth pulling in regardless:

```zsh
# Add to zshrc (missing from current setup)
setopt EXTENDED_HISTORY        # Timestamp entries
setopt HIST_IGNORE_ALL_DUPS    # No duplicates
setopt HIST_REDUCE_BLANKS      # Clean blanks
setopt EXTENDED_GLOB
setopt CORRECT                 # Command correction suggestions

# zstyle completions
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'   # Case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"   # Colorized
zstyle ':completion:*' menu select                         # Menu selection
```

Also add `zsh-history-substring-search` (not in Debian repos, git clone into oh-my-zsh custom plugins):
```bash
git clone https://github.com/zsh-users/zsh-history-substring-search.git \
  "$HOME/.oh-my-zsh/custom/plugins/zsh-history-substring-search"
```
Then add to `plugins=(... zsh-history-substring-search)` and bind:
```zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
```

Shared:
- `eval "$(zoxide init zsh --cmd cd)"`
- fzf with Catppuccin Mocha colors (already in current zshrc)
- Starship with `palette = 'catppuccin_mocha'`
- Font updated to JetBrains Mono in `kitty.conf`

---

## SDDM

```bash
# Dependencies
sudo apt install --no-install-recommends \
  qml-module-qtquick-layouts qml-module-qtquick-controls2 libqt6svg6

# Install theme
cd /tmp
curl -LOsS https://github.com/catppuccin/sddm/releases/latest/download/catppuccin-mocha-mauve.zip
unzip catppuccin-mocha-mauve.zip
sudo mv catppuccin-mocha-mauve /usr/share/sddm/themes/

# Activate (drop-in, safe rollback)
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-catppuccin.conf << 'EOF'
[Theme]
Current=catppuccin-mocha-mauve
EOF

# Preview without logging out
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/catppuccin-mocha-mauve
```

Rollback: `sudo rm /etc/sddm.conf.d/10-catppuccin.conf`

---

## GRUB

Same approach as current GNOME setup (already proven):

```bash
git clone https://github.com/catppuccin/grub.git /tmp/catppuccin-grub
sudo cp -r /tmp/catppuccin-grub/src/catppuccin-mocha-grub-theme /usr/share/grub/themes/
# Edit /etc/default/grub: GRUB_THEME="..." + GRUB_GFXMODE=1920x1080
sudo update-grub
```

---

## Dotfiles Structure (dotbot)

```
~/dotfiles/
├── install.conf.yaml  ← dotbot link/shell directives
├── install            ← dotbot bootstrap script
├── dotbot/            ← dotbot git submodule
├── kitty/
│   └── kitty.conf
├── zsh/
│   ├── zshrc
│   └── zshenv         ← XDG vars, EDITOR, PATH
├── plasma/            ← KDE-sensitive configs, linked separately
│   ├── kwinrc
│   ├── kdeglobals
│   └── kscreenlockerrc
├── kvantum/
│   └── kvantum.kvconfig
├── gtk/
│   ├── gtk-3.0-settings.ini
│   └── gtk-4.0-gtk.css
├── environment/
│   └── envvars.sh
└── scripts/
    ├── backup-plasma.sh
    └── restore-plasma.sh
```

`install.conf.yaml` maps each file to its target path. The `plasma/` links are managed as a separate dotbot profile (`install-plasma.conf.yaml`) so they can be skipped before a major KDE upgrade and re-applied after verifying compatibility.

Bootstrap:
```bash
./install                          # links all safe configs
./install -c install-plasma.conf.yaml  # links plasma/ configs
```

**Upgrade resilience:**
- Safe across dist-upgrades: kitty, zsh, starship, kvantum, gtk, environment
- Risky on major KDE bumps: `plasma/` profile — run `./install -c install-plasma.conf.yaml` only after verifying compatibility with the new KDE version

---

## Recovery & Debug

```bash
# Restart Plasma shell
systemctl --user restart plasma-plasmashell

# Reconfigure KWin without logout
qdbus org.kde.KWin /KWin reconfigure

# Disable tiling from TTY if session is broken
kwriteconfig6 --file kwinrc --group Plugins --key krohnkiteEnabled false

# Disable all extensions from TTY
# (Edit kwinrc manually: set all *Enabled keys to false)

# Nuclear: remove all Plasma customization
rm ~/.config/plasma-org.kde.plasma.desktop-appletsrc
rm ~/.config/kwinrc ~/.config/kdeglobals
# Log out → clean default Plasma session
```

**NEVER restart `kwin_wayland` directly** — it crashes the session. Log out instead.

---

## What We're Not Carrying Over from GNOME

| GNOME feature | KDE equivalent / status |
|---------------|------------------------|
| Open Bar island pills | KDE floating panel (different aesthetic) |
| Neon glow border CSS | Not applicable — KDE uses Aurorae decorations |
| Burn My Windows glitch effect | KWin has built-in effects; glitch effect not available natively |
| macOS traffic light buttons (GTK CSS) | Aurorae or Breeze window buttons instead |
| 6-variant dconf system | See accent decision below |
| `_write_dock_neon_border_css` | Removed |
| `_create_burn_my_windows_profile` | Removed |
| `gnome-extensions.sh` | Removed |

---

## Locked Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **D1 Accent** | Single: **Mauve** `#cba6f7` | Simpler setup, best contrast on Mocha dark surfaces, matches both KDE reports |
| **D2 Font** | **JetBrains Mono Nerd Font** | Better Nerd Font glyph coverage, both KDE reports recommend, APT-available (base) + manual Nerd install |
| **D3 Tiling** | **Krohnkite** (auto-tiling) | dwm-style dynamic tiling, vim keybindings (Meta+H/J/K/L), active KWin 6 fork |
| **D4 Shell** | **Keep oh-my-zsh** | No framework change — terminal stack is DE-agnostic, avoid scope creep |
| **D5 Opacity** | **0.90** | More readable on the `evening-sky.png` wallpaper; still clearly transparent with real KWin blur |
| **D6 Wallpaper** | **Keep `evening-sky.png`** | Already in repo, familiar |

Papirus folder accent: `cat-mocha-mauve`
catppuccin/kde install args: `./install.sh 1 4 1` (Mocha=1, Mauve=4, Modern=1)
catppuccin/kvantum: `Catppuccin-Mocha-Mauve`
catppuccin/sddm: `catppuccin-mocha-mauve`
catppuccin/cursors: `catppuccin-mocha-mauve-cursors`

---

## Rewrite Scope vs Current GNOME Setup

| File | Action |
|------|--------|
| `setup.sh` | Major rewrite — replace GNOME-specific functions with KDE equivalents |
| `gnome/gnome-extensions.sh` | Delete |
| `gnome/dconf/` | Delete |
| `gnome/dock-neon-border.css` | Delete |
| `kitty/kitty.conf` | Update: add `background_blur 64`, adjust opacity |
| `zshrc` | Update or replace depending on §D4 |
| `starship.toml` | Minor updates (font glyphs if §D2) |
| `install.conf.yaml` | Update symlink targets |
| `KDE_MIGRATION_PLAN.md` | This file → evolves into README sections |

New files:
- `plasma/` dotbot profile configs (kwinrc, kdeglobals, kscreenlockerrc)
- `kvantum/kvantum.kvconfig`
- `environment/envvars.sh`
- `install-plasma.conf.yaml` (separate dotbot profile for KDE-sensitive links)
- `scripts/backup-plasma.sh`
- `scripts/restore-plasma.sh`
