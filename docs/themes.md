# Theme Switching

This repository uses a modular theme runtime for user-space theming.

## Supported Themes (v1)

Only `catppuccin` is fully implemented. Two additional entries (`rosepine`, `tokyonight`) exist as unsupported placeholders in the catalog and will be rejected with an error if selected.

### catppuccin

- Flavors: `latte`, `frappe`, `macchiato`, `mocha`
- Accents: `rosewater`, `flamingo`, `pink`, `mauve`, `red`, `maroon`, `peach`, `yellow`, `green`, `teal`, `sky`, `sapphire`, `blue`, `lavender`

## Install-Time Selection

```bash
./setup.sh --theme catppuccin --flavor mocha --accent mauve
```

If omitted, defaults are `catppuccin/mocha/mauve`.

## Post-Install Commands

List supported combinations:

```bash
bash scripts/theme-switch.sh --list
```

Show current applied state (displays per-adapter status and any pending restart warning):

```bash
bash scripts/theme-switch.sh --current
```

Switch theme:

```bash
bash scripts/theme-switch.sh --theme catppuccin --flavor frappe --accent blue --non-interactive
```

Preview operations without writing:

```bash
bash scripts/theme-switch.sh --theme catppuccin --flavor macchiato --accent lavender --dry-run
```

All CLI flags:

| Flag | Description |
|---|---|
| `--theme <name>` | Theme family to apply |
| `--flavor <name>` | Flavor variant |
| `--accent <name>` | Accent color |
| `--list` | Print all supported theme/flavor/accent combinations |
| `--current` | Print the last applied state and per-adapter status |
| `--dry-run` | Print what would be done without writing any files |
| `--non-interactive` | Skip any interactive prompts |
| `-h`, `--help` | Show usage |

## Adapters

The switcher runs six adapters in order. Each is independent; a failure in one does not block the others.

### kde

Applies the full KDE/Qt visual stack for `catppuccin`:

- Clones `catppuccin/kde` and runs `install.sh` to install the color scheme and look-and-feel package.
- Applies `plasma-apply-colorscheme` and `plasma-apply-lookandfeel`.
- Sets the lock screen greeter theme via `kwriteconfig6`.
- Clones `catppuccin/kvantum`, installs the matching theme directory under `~/.config/Kvantum/`, and activates it with `kvantummanager`.
- Sets the KDE widget style to `kvantum` in `kdeglobals`.
- Runs the `catppuccin/gtk` v1.0.3 installer for the selected flavor/accent and applies Flatpak GTK/icon overrides.
- Clones `catppuccin/papirus-folders`, copies accent icons, and sets the folder color via `papirus-folders`.
- Writes `~/.config/gtk-3.0/settings.ini` from a template.
- Sets the icon theme to `Papirus-Dark` and the default terminal to `kitty` in `kdeglobals`.

### terminal

- Ensures `~/.config/kitty/kitty.conf` includes `./theme.conf`.
- Renders `~/.config/kitty/theme.conf` from a template with palette tokens for the selected flavor/accent.
- Renders `~/.config/starship.toml` from a template.

### editors

- Writes `~/.config/nvim/lua/colorscheme-flavor.lua` (gitignored) with a single line:
  ```lua
  return "<flavor>"
  ```
  The Neovim colorscheme plugin reads this file at startup to select the correct Catppuccin flavor. The tracked file `nvim/lua/plugins/colorscheme.lua` is not modified.

### cli

- Downloads the matching `bat` `.tmTheme` file from `catppuccin/bat` and rebuilds the bat cache.
- Writes or updates `~/.config/bat/config` to set `--theme`.
- Downloads the matching `btop` `.theme` file from `catppuccin/btop`.
- Writes or updates `~/.config/btop/btop.conf` to set `color_theme`.
- Sets `delta.syntax-theme` in the global git config.
- Renders `~/.config/fzf/colors.zsh` from a template for fzf color integration.

### apps

Only runs for the `catppuccin` theme family.

- **Firefox**: Downloads the `catppuccin_<flavor>_<accent>.xpi` from `catppuccin/firefox` releases and installs it system-wide under `/usr/lib/firefox*/distribution/extensions/`. Manual activation is still required inside the Firefox Add-ons UI if the extension does not activate automatically.
- **TIDAL Hi-Fi**: Renders `~/.config/tidal-hifi/catppuccin-<flavor>-<accent>.css` from a template and copies it to `~/.config/tidal-hifi/catppuccin.css`. Manual activation is required in tidal-hifi Settings > Theming. Also writes a `.desktop` override at `~/.local/share/applications/com.mastermindzh.tidal-hifi.desktop` with correct Wayland flags.
- **Rofi**: Downloads the adi1090x `type-2/style-9` launcher layout and the `catppuccin.rasi` color preset, patches `shared/colors.rasi` to import the catppuccin preset, and renders `~/.config/rofi/config.rasi` from a template.

### panel

Applies Panel Colorizer widget colors for the top bar. Requires a live Plasma session with the `luisbocanegra.panel.colorizer` applet loaded.

- Renders a global settings JSON from a template and writes it to `~/.config/linux-setup/panel-colorizer-global.json`.
- Detects the top panel and Panel Colorizer applet IDs via `qdbus6`/`qdbus`.
- Applies per-widget colors and global settings via `panel-colorizer-apply.py`.
- If no desktop session is detected (`$DISPLAY` and `$WAYLAND_DISPLAY` are both unset), or if the Panel Colorizer applet cannot be found, the adapter exits with code 2. The switcher records `restart_pending: true` in state and the autostart script `scripts/apply-panel-colorizer.sh` will reapply the panel on next login automatically.

To trigger a manual panel reapply without re-running all adapters:

```bash
bash scripts/apply-panel-colorizer.sh
```

## Runtime State

The switcher persists two files under `~/.config/linux-setup/`:

- `theme-state.json` — last applied selection and adapter results
- `theme-context.json` — full resolved context (palette tokens, derived values, widget colors) for the last run

### theme-state.json schema

| Field | Type | Description |
|---|---|---|
| `theme` | string | Theme family name |
| `flavor` | string | Flavor variant |
| `accent` | string | Accent color name |
| `status` | string | `applied`, `partial`, or `failed` |
| `completed_adapters` | array | Names of adapters that succeeded |
| `restart_pending` | boolean | True if panel apply was deferred |
| `last_applied` | string | ISO8601 UTC timestamp |

## v1 Caveats

- SDDM and GRUB remain setup-managed and are not switched post-install.
- Firefox and tidal-hifi require manual activation in each app UI after the adapter installs or generates their theme files.
- The panel adapter sets `restart_pending: true` when it cannot reach the Panel Colorizer applet. The autostart script `scripts/apply-panel-colorizer.sh` handles reapplication on the next login session automatically; no manual intervention is needed unless the autostart is not registered.
- `rosepine` and `tokyonight` appear in `--list` output as unsupported placeholders and cannot be selected.
