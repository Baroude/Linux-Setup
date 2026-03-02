# Linux Setup — KDE Plasma 6

A fully automated, idempotent dotfiles setup for **Debian 13** running **KDE Plasma 6 on Wayland**.
Theme: **Catppuccin Mocha Mauve** end-to-end (shell, terminal, KDE, GTK, GRUB, SDDM).

---

## Stack

| Layer | Choice |
|---|---|
| DE | KDE Plasma 6 (Wayland) |
| Theme | Catppuccin Mocha — accent Mauve `#cba6f7` |
| Terminal | Kitty (opacity 0.90, blur 64) |
| Shell | Zsh + oh-my-zsh |
| Prompt | Starship — Catppuccin Powerline |
| Tiling | Krohnkite (vim-key moves, 8 px gaps) |
| Editor | Neovim (latest stable) |
| UI font | Inter |
| Mono font | JetBrains Mono Nerd Font |

---

## Quick start

> Requires Debian 13, KDE Plasma 6 already installed, and a user with `sudo`.

```bash
git clone https://github.com/Baroude/Linux-Setup ~/.dotfiles
cd ~/.dotfiles
./setup.sh
```

The script is **idempotent** — safe to re-run at any time. Already-installed
components are detected and skipped.

After the script finishes, optionally link plasma config files (kwinrc,
kdeglobals, kscreenlockerrc). Skip this before a major KDE upgrade:

```bash
./install -c install-plasma.conf.yaml
```

---

## What `setup.sh` does

| Phase | What happens |
|---|---|
| 1 | APT base packages (git, zsh, kitty, fzf, zoxide, kvantum, papirus, fastfetch…) |
| 1b | Node.js LTS via nodesource (skipped if already present) |
| 1c | Neovim latest stable prebuilt + LSP tools (skipped if already at latest) |
| 2 | Fonts — Inter (APT) + JetBrains Mono Nerd Font (skipped if already present) |
| 3 | catppuccin/kde — global theme, color scheme, window decorations, cursors |
| 4 | Kvantum — `catppuccin-mocha-mauve` Qt app style |
| 5 | GTK bridge — catppuccin/gtk v1.0.3 + Flatpak overrides |
| 6 | Icons — Papirus-Dark + catppuccin papirus-folders (cat-mocha-mauve) |
| 7 | KWin — blur (strength 9, noise 2) + rounded corners (radius 12) |
| 8 | Krohnkite tiling script (install or upgrade) + 8 px gaps |
| 9 | Dock — floating bottom panel (Icons-only Task Manager + tray + clock) |
| 10 | Kitty config directory (dotbot links `kitty/kitty.conf`) |
| 11 | Zsh + oh-my-zsh + plugins + Starship |
| 12 | SDDM — catppuccin-mocha-mauve theme + evening-sky wallpaper |
| 13 | GRUB — catppuccin-mocha theme |
| 14 | Dotbot — links all dotfiles, applies desktop + lock screen wallpaper |

---

## Dotfiles layout

```
Linux-Setup/
├── setup.sh                  # Full automated setup (14 phases)
├── install                   # Dotbot bootstrap
├── install.conf.yaml         # Base dotbot links (always safe)
├── install-plasma.conf.yaml  # Plasma-specific links (skip before KDE upgrade)
├── zshrc                     # → ~/.zshrc
├── starship.toml             # → ~/.config/starship.toml
├── gitconfig                 # → ~/.gitconfig
├── kitty/kitty.conf          # → ~/.config/kitty/kitty.conf
├── zsh/zshenv                # → ~/.zshenv
├── fastfetch/                # → ~/.config/fastfetch/
├── plasma/                   # kwinrc, kdeglobals, kscreenlockerrc
├── kvantum/kvantum.kvconfig  # → ~/.config/Kvantum/kvantum.kvconfig
├── gtk/                      # gtk-3.0-settings.ini, gtk-4.0-gtk.css
├── environment/envvars.sh    # → ~/.config/plasma-workspace/env/envvars.sh
├── images/evening-sky.png    # Wallpaper (desktop, lock screen, SDDM)
└── scripts/
    ├── configure-dock.sh     # Plasma JS script — rebuilds the dock
    ├── backup-plasma.sh      # Copies live KDE configs back into repo
    └── restore-plasma.sh     # Re-runs install-plasma profile
```

---

## Keyboard shortcuts

### KDE Plasma (global)

| Shortcut | Action |
|---|---|
| `Meta + Tab` | Switch between windows (KWin switcher) |
| `Meta + ~` | Switch between windows of same application |
| `Meta + D` | Show desktop |
| `Meta + L` | Lock screen |
| `Meta + Space` | KRunner (app launcher / search) |
| `Meta + E` | Open file manager (Dolphin) |
| `Meta + Shift + Q` | Close active window |
| `Meta + PgUp/PgDn` | Move window to previous/next virtual desktop |
| `Ctrl + F1–F4` | Switch to virtual desktop 1–4 |
| `Meta + Arrow` | Snap window to half screen (KWin built-in) |

### Krohnkite — tiling

Krohnkite uses `Meta` as the modifier and vim-style keys for movement.

| Shortcut | Action |
|---|---|
| `Meta + J` | Focus next tile (down) |
| `Meta + K` | Focus previous tile (up) |
| `Meta + H` | Focus tile to the left |
| `Meta + L` | Focus tile to the right |
| `Meta + Shift + J` | Move tile down in the stack |
| `Meta + Shift + K` | Move tile up in the stack |
| `Meta + Shift + H` | Move tile left / shrink master area |
| `Meta + Shift + L` | Move tile right / grow master area |
| `Meta + Enter` | Promote focused window to master |
| `Meta + T` | Toggle tiling on/off for the current desktop |
| `Meta + F` | Toggle float for the focused window |
| `Meta + \` | Cycle through tiling layouts |
| `Meta + ,` | Decrease number of master windows |
| `Meta + .` | Increase number of master windows |
| `Meta + I` | Increase gap size |
| `Meta + U` | Decrease gap size |

> Gaps are set to **8 px** by default (tile gap + all screen edges). Adjust
> in **System Settings → KWin Scripts → Krohnkite → Configure**.

### Kitty terminal

| Shortcut | Action |
|---|---|
| `Ctrl + Shift + T` | New tab |
| `Ctrl + Shift + W` | Close tab |
| `Ctrl + Shift + →/←` | Next / previous tab |
| `Ctrl + Shift + Enter` | New window (split) |
| `Ctrl + Shift + ]` / `[` | Next / previous window |
| `Ctrl + Shift + C/V` | Copy / paste |
| `Ctrl + Shift + +/-` | Increase / decrease font size |
| `Ctrl + Shift + F11` | Toggle fullscreen |

### Zsh + oh-my-zsh

| Shortcut | Action |
|---|---|
| `Ctrl + R` | Fuzzy history search (fzf) |
| `↑ / ↓` | History substring search (type prefix first) |
| `Ctrl + T` | fzf file picker |
| `Alt + C` | fzf cd into subdirectory |
| `z <name>` | Jump to frecent directory (zoxide) |

---

## Applying changes without logging out

```bash
# Reload KWin (tiling, blur, corners)
qdbus6 org.kde.KWin /KWin reconfigure

# Re-link dotfiles
./install

# Re-link plasma configs
./install -c install-plasma.conf.yaml

# Backup current live plasma config back into the repo
./scripts/backup-plasma.sh
```

---

## Manual steps after first run

1. **Dock** — Phase 9 runs automatically, but verify the floating bottom
   panel has: Icons-only Task Manager + System Tray + Digital Clock.
2. **Krohnkite** — review gaps and layout keybinds in
   System Settings → KWin Scripts → Krohnkite → Configure.
3. **Restart session** to apply SDDM theme and all environment variables.
