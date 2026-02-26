# Linux-Setup

## Requirements

To use the bootstrap scripts you need:
- `apt` package manager
- user allowed to run `sudo`
- GNOME session for desktop theming steps (`setup.sh` path)

## Installation

Desktop / GNOME path:

```bash
./setup.sh
./install
```

To use a specific Catppuccin variant (default: `mocha-blue`):

```bash
CATPPUCCIN_VARIANT=mocha-teal ./setup.sh
```

## Catppuccin Variants

Six variants are supported across two base flavors:

| Variant | Flavor | Accent color | Hex | Papirus folders |
|---|---|---|---|---|
| `mocha-blue` *(default)* | Mocha | Blue | `#89b4fa` | blue |
| `mocha-mauve` | Mocha | Mauve | `#cba6f7` | violet |
| `mocha-teal` | Mocha | Teal | `#94e2d5` | teal |
| `macchiato-blue` | Macchiato | Blue | `#8aadf4` | blue |
| `macchiato-mauve` | Macchiato | Mauve | `#c6a0f6` | violet |
| `macchiato-teal` | Macchiato | Teal | `#8bd5ca` | teal |

**Flavor differences:**
- **Mocha** — darkest base (`#1e1e2e`), highest contrast, most popular Catppuccin flavor
- **Macchiato** — slightly lighter base (`#24273a`), softer feel with a blue-tinted dark background

**What the accent color controls:**
- GTK window theme (title bars, buttons, selections)
- Dock neon-border glow and running-indicator dots
- Tiling Shell window border
- Open Bar top-bar pill border and accent highlights
- Catppuccin cursor set
- Papirus folder icon color
- Starship prompt git pill and `❯` character colors

WSL path:

```bash
./wsl.sh
./install
```

## Migration Notes

- Terminal is now `kitty` (`~/.config/kitty`) instead of Terminator.
- Neovim now uses `lazy.nvim` and Lua config files in `nvim/lua/plugins`.
- LSP TypeScript server moved from `tsserver` to `ts_ls`.
- First Neovim launch installs plugins automatically.
- Firefox Catppuccin Mocha theme remains a manual/sync step:
  https://addons.mozilla.org/firefox/addon/catppuccin-mocha-mauve/

## Rollback

Return to the pre-migration baseline from git:

```bash
git switch main
git submodule update --init --recursive
```

Restore specific files while staying on this branch:

```bash
git restore setup.sh wsl.sh install.conf.yaml starship.toml nvim/
git submodule update --init --recursive dotbot
```
