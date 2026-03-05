# Linux Setup — KDE Plasma 6

A fully automated, idempotent dotfiles setup for **Debian 13** running **KDE Plasma 6 on Wayland**.
Theme system: **Catppuccin modular switching** (default: `mocha/mauve`) for KDE, GTK, Kvantum, terminal, prompt, editors, CLI tools, Firefox, and tidal-hifi CSS.

---

## Stack

| Layer | Choice |
|---|---|
| DE | KDE Plasma 6 (Wayland) |
| Theme | Catppuccin modular (default: Mocha + Mauve) |
| Terminal | Kitty (opacity 0.90, blur 64) |
| Shell | Zsh + oh-my-zsh |
| Prompt | Starship — Catppuccin Powerline |
| Tiling | Krohnkite (vim-key moves, 8 px gaps) |
| Blur | kwin-better-blur (force-blurs semi-transparent windows incl. Dolphin) |
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

Optional theme selection at install time:

```bash
./setup.sh --theme catppuccin --flavor macchiato --accent blue
```

The script is **idempotent** — safe to re-run at any time. Already-installed
components are detected and skipped.

After the script finishes, optionally link plasma config files (kwinrc,
kscreenlockerrc, kwinrulesrc). Skip this before a major KDE upgrade:

```bash
./install -c install-plasma.conf.yaml
```

Note: `starship.toml`, `~/.config/Kvantum/kvantum.kvconfig`, `~/.config/gtk-3.0/settings.ini`, and `kdeglobals` are now theme-managed outputs written by `scripts/theme-switch.sh` (not Dotbot-linked targets).

---

## What `setup.sh` does

| Phase | What happens |
|---|---|
| 1 | APT base packages (git, zsh, kitty, rofi-wayland, fzf, zoxide, kvantum, papirus, fastfetch…) |
| 1b | Node.js LTS via nodesource (skipped if already present) |
| 1c | Neovim latest stable prebuilt + LSP tools (skipped if already at latest) |
| 2 | Fonts — Inter (APT) + JetBrains Mono Nerd Font (skipped if already present) |
| 3 | Modular theme apply deferred to `scripts/theme-switch.sh` (Phase 14b) |
| 6 | Dock icon assets (`catppuccin-vibes`) + launcher overrides |
| 6b | Firefox — install Catppuccin Mocha Mauve theme extension (system-wide) |
| 7 | KWin — blur (strength 9, noise 2) + rounded corners (radius 12) + Dolphin opacity rule |
| 7b | kwin-better-blur built from source (forces blur behind any semi-transparent window) |
| 8 | Krohnkite tiling script (install or upgrade) + 8 px gaps (`screenGapBetween` + screen edges) |
| 8b | Rofi launcher shortcut (prefers `Meta + Space`, falls back only on conflicts) |
| 9 | Dock — floating bottom panel (Icons-only Task Manager + tray + clock) |
| 10 | Kitty config directory (dotbot links `kitty/kitty.conf`) |
| 11 | Zsh + oh-my-zsh + plugins + Starship |
| 11b | Tidal (tidal-hifi Flatpak), Wayland launcher override, and generated Catppuccin CSS |
| 12 | SDDM — catppuccin-mocha-mauve theme + evening-sky wallpaper |
| 13 | GRUB — catppuccin-mocha theme |
| 14 | Dotbot links base dotfiles + `theme-switch.sh` applies selected theme |

---

## Theme Commands

```bash
# List supported combinations
bash scripts/theme-switch.sh --list

# Show active state
bash scripts/theme-switch.sh --current

# Switch post-install
bash scripts/theme-switch.sh --theme catppuccin --flavor frappe --accent lavender --non-interactive

# Preview only
bash scripts/theme-switch.sh --theme catppuccin --flavor mocha --accent mauve --dry-run
```

Full details: `docs/themes.md`

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
    ├── configure-rofi-shortcut.sh  # Assigns rofi global shortcut after conflict scan
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
| `Meta + Space` | Rofi app launcher (`rofi-wayland` or `rofi`, `-show drun`) when available |
| `Meta + E` | Open file manager (Dolphin) |
| `Meta + Shift + Q` | Close active window |
| `Meta + PgUp/PgDn` | Move window to previous/next virtual desktop |
| `Ctrl + F1–F4` | Switch to virtual desktop 1–4 |
| `Meta + Arrow` | Snap window to half screen (KWin built-in) |

If `Meta + Space` is already taken by a non-KRunner action, setup falls back to
the first free binding in: `Meta + R`, `Meta + /`, `Alt + Space`.

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
2. **kwin-better-blur** — go to System Settings → Desktop Effects → Better Blur
   → Configure → enable **Blur all windows** and set blur strength to taste
   (10–15 is a good starting point). The stock KWin blur effect is disabled
   intentionally — better-blur replaces it entirely.
3. **Krohnkite** — review gaps and layout keybinds in
   System Settings → KWin Scripts → Krohnkite → Configure.
4. **Firefox/TIDAL activation** — if Firefox keeps the default look, open
   Add-ons and Themes and select the generated Catppuccin variant.
   For TIDAL, open Settings -> Theming and choose
   `~/.config/tidal-hifi/catppuccin.css`.
5. **Restart session** to apply SDDM theme and all environment variables.
