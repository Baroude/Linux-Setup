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
