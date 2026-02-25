# Linux-Setup Migration Plan (2026)

Last reviewed: 2026-02-25

## Progress Log

### 2026-02-25 (Phase 2.5: GNOME Extensions)

- Added `gnome/gnome-extensions.sh` — installs and enables Open Bar, Blur my Shell, Dash to Dock, Tiling Shell via `gext` (gnome-extensions-cli); loads dconf settings from baseline file.
- Added `gnome/dconf/extensions.conf` — version-controlled dconf baseline for all four extensions (Catppuccin Mocha color values baked in).
- Wired extension script into `setup.sh` `apply_catppuccin_theme()` with live-session guard (skips gracefully when no display, prints manual run hint).

### 2026-02-24 (Implementation Started)

- Created branch `migration/2026-modernize`.
- Updated `dotbot` submodule pointer from `ac5793c` to `v1.24.0` (`08ba8ac`).
- Rewrote `setup.sh` and `wsl.sh` for non-interactive/idempotent bootstrap:
  - Node.js moved to NodeSource `setup_lts.x`.
  - Neovim now installs from latest stable release artifacts (no source build from `master`).
  - Removed automatic `nvimUpdate.sh` cron wiring from bootstrap path.
  - Replaced hard-coded repo paths with dynamic `SCRIPT_DIR`.
  - Added Catppuccin GTK/icon/cursor apply flow in GNOME path.
- Updated Dotbot links to use Kitty instead of Terminator and added `kitty/kitty.conf` (Catppuccin Mocha + Iosevka).
- Replaced `starship.toml` palette with Catppuccin Mocha colors.
- Migrated Neovim config from vim-plug to `lazy.nvim`:
  - Added `nvim/init.lua` entrypoint.
  - Added modular `lua/config/*.lua` + `lua/plugins/*.lua`.
  - Removed legacy vim-plug files.
  - Updated LSP config to `vim.lsp.config` / `vim.lsp.enable` and renamed `tsserver` -> `ts_ls`.
  - Switched colorscheme to Catppuccin Mocha.
- Validation note: `bash install -n` is currently blocked in this Windows checkout by CRLF line endings in `install`; Dotbot functional validation is still pending on a Linux/WSL shell with LF scripts.

## Goals

1. Move installers to currently supported software versions (Node.js, Neovim, language servers).
2. Replace Terminator with Kitty while keeping Starship + zsh.
3. Migrate Neovim plugin management from vim-plug to lazy.nvim and update outdated plugin/server names.
4. Standardize visual theming on Catppuccin Mocha.

## Fixed Decisions

- Keep Dotbot as the dotfile linker/orchestrator.
- Upgrade Dotbot submodule to a current release before applying config changes.
- Keep bootstrap scripts non-interactive and rerunnable (idempotent).
- Track stable channels (updatable), not hard-pinned versions.
- Do not lock Neovim plugin versions in-repo (`lazy-lock.json` not committed).
- Use Catppuccin Mocha as the single default flavor for terminal, shell prompt, and Neovim.
- Use `Papirus-Dark` icons with Catppuccin folder accents.
- Use Catppuccin cursor theme (Mocha variant).
- Use Catppuccin Mocha theme in Firefox for browser consistency.
- Stay on GNOME (Debian 13) as the desktop environment.
- Customize top bar/dock/workflow through GNOME extensions, managed by scripts where possible.

## Current State (Repo Snapshot)

Baseline captured before the 2026-02-24 implementation pass.

- Node install is pinned to `setup_16.x` in [`setup.sh`](./setup.sh) and [`wsl.sh`](./wsl.sh), which is EOL.
- Neovim is built from `master` source and updated by cron (`nvimUpdate.sh`), which is non-deterministic.
- Terminal config is currently Terminator (`terminator/config`) linked by Dotbot.
- Theme stack is mixed (Nordic GTK + Everforest + Tokyo-like prompt), not unified.
- Neovim plugins use vim-plug and include old repo names (`scrooloose/*`, `kyazdani42/*`).
- LSP config uses `tsserver` and legacy `require('lspconfig').*.setup{}` style.

## Target Versions / Channels

Use supported channels, not frozen old branches:

| Component | Target |
|---|---|
| Node.js | `v24` Active LTS (or `setup_lts.x`) |
| Neovim | Stable release line (`v0.11.x`, currently `0.11.6`) |
| npm global LSP tools | `typescript`, `typescript-language-server`, `bash-language-server`, `pyright` |
| Starship | Latest stable release channel |
| Kitty | Latest stable release channel |
| zsh | distro-supported stable (minimum `5.9+`) |
| Theme flavor | Catppuccin `mocha` |

## Migration Phases

### Phase 0: Safety + Branching

- Create branch: `migration/2026-modernize`.
- Keep a full backup of current `nvim/`, `terminator/`, `setup.sh`, `wsl.sh`.
- Add a rollback section in README with restore commands.

### Phase 1: Installer Modernization (`setup.sh`, `wsl.sh`)

- Keep Dotbot bootstrap in `install` and update submodule revision (`dotbot/`) to latest stable tag.
- Make bootstrap fully non-interactive by default:
  - Avoid commands that prompt during install.
  - Support unattended runs on fresh machines and reruns.
- Replace Node 16 block with LTS install flow:
  - `curl -fsSL https://deb.nodesource.com/setup_lts.x -o nodesource_setup.sh`
  - `sudo -E bash nodesource_setup.sh`
  - `sudo apt install -y nodejs`
- Stop building Neovim from repo `master` in bootstrap scripts.
- Install Neovim from stable release artifacts (or trusted package source that tracks stable).
- Remove weekly Neovim cron auto-build (`nvimUpdate.sh`) from default setup path.
- Make scripts idempotent:
  - Check before cloning plugins/repos.
  - Use `mkdir -p`.
  - Avoid failing when rerun.
- Resolve hard-coded paths (`/home/mathias/...`) by deriving script directory (`SCRIPT_DIR="$(cd ...)"`).
- Replace Nordic theme installation/apply block with Catppuccin GTK apply flow (GNOME path only).

### Phase 2: Terminator -> Kitty (with Starship + zsh)

- Add `kitty/kitty.conf` and migrate settings:
  - Font: Iosevka
  - Theme/palette: Catppuccin Mocha
  - Opacity/background behavior
  - Split/navigation keybind equivalents
- Update Dotbot links in `install.conf.yaml`:
  - Remove `~/.config/terminator : terminator`
  - Add `~/.config/kitty : kitty`
- Keep Starship config in `~/.config/starship.toml` (already aligned with zsh).
- Replace prompt palette in `starship.toml` with Catppuccin Mocha colors (or Starship Catppuccin preset baseline).
- Keep zsh startup line:
  - `eval "$(starship init zsh)"`
- Optional: keep Terminator config for one release cycle as fallback, then remove.

### Phase 2.5: GNOME UX Customization (Extensions)

- Keep GNOME Shell as the desktop session target.
- Add an extension profile for:
  - top bar customization
  - dock behavior (auto-hide, position, icon sizing)
  - application launcher/search UX
- Install/apply desktop icon and cursor themes:
  - icon theme: `Papirus-Dark` with Catppuccin folder accents
  - cursor theme: Catppuccin cursors (Mocha)
- Script GNOME settings with `gsettings`/`dconf` where stable.
- For extensions, script install/enable/disable where possible and keep a documented fallback manual step.
- Export and version control a baseline GNOME settings dump for repeatable restore on new machines.
- Add browser theming step for Firefox:
  - install Catppuccin Mocha theme from Firefox Add-ons
  - keep this as a documented manual step (sync-friendly)

### Phase 3: vim-plug -> lazy.nvim

- Replace `init.vim` entrypoint with `init.lua`.
- Bootstrap lazy.nvim using stable branch per docs.
- Move plugin specs into `lua/plugins/*.lua`.
- Keep plugins updatable (no repository lockfile commit for plugin versions).

Required plugin/repo updates:

| Current | Target |
|---|---|
| `kyazdani42/nvim-tree.lua` | `nvim-tree/nvim-tree.lua` |
| `kyazdani42/nvim-web-devicons` | `nvim-tree/nvim-web-devicons` |
| `scrooloose/NERDTree` | Remove (recommended) or `preservim/nerdtree` |

Recommended cleanup during migration:

- Remove `NERDTree` because `nvim-tree` is already used.
- Consider removing `vim-polyglot` if Treesitter coverage is sufficient.
- Keep existing functional plugins first; optimize lazy-loading after parity is reached.
- Replace Everforest colorscheme with Catppuccin:
  - Add plugin `catppuccin/nvim` (lazy spec name `catppuccin`, high priority).
  - Set `flavour = "mocha"` and `colorscheme catppuccin`.

LSP modernization (Neovim 0.11+):

- Migrate from:
  - `require('lspconfig').<server>.setup{}`
- To:
  - `vim.lsp.config('<server>', {...})`
  - `vim.lsp.enable('<server>')`
- Rename TypeScript server in config from `tsserver` to `ts_ls`.

### Phase 4: Validation + Cutover

- Fresh machine/WSL test:
  - `./setup.sh` or `./wsl.sh`
  - `./install`
- Verify:
  - `node -v` shows supported line (v24.x LTS target)
  - `nvim --version` shows target stable
  - `kitty --version` works
  - `zsh --version` works and Starship renders
  - Kitty colors match Catppuccin Mocha reference palette
  - Neovim uses Catppuccin Mocha (`:colorscheme` check)
  - GNOME icon/cursor themes are applied (`Papirus-Dark` + Catppuccin cursor)
  - Firefox theme is Catppuccin Mocha
  - `:checkhealth` and `:checkhealth lazy` pass in Neovim
  - LSP attach for Python/TS/Bash/C/Go works

## Deliverables Checklist

- [x] Updated `setup.sh`
- [x] Updated `wsl.sh`
- [x] Bootstrap scripts run non-interactively and are idempotent
- [x] Updated `install.conf.yaml`
- [x] New `kitty/kitty.conf`
- [x] Updated `starship.toml` (Catppuccin Mocha)
- [x] Added GNOME extension customization profile (Open Bar, Blur my Shell, Dash to Dock, Tiling Shell)
- [x] Added scripted GNOME settings apply step (`gsettings`/`dconf`)
- [x] Added icon theme install/apply step (`Papirus-Dark` + Catppuccin folders)
- [x] Added cursor theme install/apply step (Catppuccin cursors, Mocha)
- [x] Added Firefox Catppuccin Mocha theme step (documented/manual)
- [x] New Lua-based Neovim config with lazy.nvim
- [x] Removed/retired `vim-plug` files
- [x] Updated plugin names and `ts_ls`
- [x] Updated Neovim colorscheme to Catppuccin Mocha
- [ ] Updated Dotbot submodule revision and validated `./install`
- [x] Updated README migration/install notes

## References

- Node.js release status: https://nodejs.org/en/about/releases/
- Node.js download channels: https://nodejs.org/en/download
- NodeSource distro installer docs: https://github.com/nodesource/distributions/blob/master/DEV_README.md
- Neovim latest release: https://github.com/neovim/neovim/releases/latest
- nvim-lspconfig migration note: https://raw.githubusercontent.com/neovim/nvim-lspconfig/master/README.md
- `ts_ls` config: https://raw.githubusercontent.com/neovim/nvim-lspconfig/master/lsp/ts_ls.lua
- lazy.nvim install/migration docs: https://lazy.folke.io/installation and https://lazy.folke.io/usage/migration
- kitty install docs: https://sw.kovidgoyal.net/kitty/binary/
- kitty releases: https://github.com/kovidgoyal/kitty/releases
- starship releases: https://github.com/starship/starship/releases
- Dotbot releases: https://github.com/anishathalye/dotbot/releases
- nvim-tree repo move target: https://github.com/nvim-tree/nvim-tree.lua
- NERDTree canonical repo: https://github.com/preservim/nerdtree
- Catppuccin ports index: https://catppuccin.com/ports/
- Catppuccin for Kitty: https://github.com/catppuccin/kitty
- Catppuccin for Neovim: https://github.com/catppuccin/nvim
- Catppuccin GTK Theme: https://github.com/Fausto-Korpsvart/Catppuccin-GTK-Theme
- Catppuccin for Firefox: https://github.com/catppuccin/firefox
- Catppuccin Cursors: https://github.com/catppuccin/cursors
- Papirus icon theme: https://github.com/PapirusDevelopmentTeam/papirus-icon-theme
