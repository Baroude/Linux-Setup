# Theme Switching

This repository uses a modular theme runtime for user-space theming.

## Supported Themes

Three theme families are fully implemented.

### catppuccin

- Flavors: `latte`, `frappe`, `macchiato`, `mocha`
- Accents: `rosewater`, `flamingo`, `pink`, `mauve`, `red`, `maroon`, `peach`, `yellow`, `green`, `teal`, `sky`, `sapphire`, `blue`, `lavender`

### rosepine

- Flavors: `main`, `moon`, `dawn` (`dawn` is the light variant)
- Accents: `love`, `gold`, `rose`, `pine`, `foam`, `iris`
- Note: Kvantum is skipped for Rose Pine (no official theme). The widget style remains whatever was last set.

### tokyonight

- Flavors: `night`, `storm`, `moon`, `day` (`day` is the light variant)
- Accents: `default` — Tokyo Night has no accent concept; `default` maps to the theme's blue. Accent-specific installer steps (e.g. Firefox XPI filename) are skipped.
- Note: No Firefox extension is available for Tokyo Night; the Firefox step is skipped automatically.

## `--list` output

```
theme: catppuccin
  flavors: latte, frappe, macchiato, mocha
  accents: rosewater, flamingo, pink, mauve, red, maroon, peach, yellow, green, teal, sky, sapphire, blue, lavender
theme: rosepine
  flavors: main, moon, dawn
  accents: love, gold, rose, pine, foam, iris
theme: tokyonight
  flavors: night, storm, moon, day
  accents: default
```

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
bash scripts/theme-switch.sh --theme rosepine --flavor moon --accent iris
bash scripts/theme-switch.sh --theme tokyonight --flavor night --accent default
bash scripts/theme-switch.sh --theme catppuccin --flavor frappe --accent blue --non-interactive
```

Preview operations without writing:

```bash
bash scripts/theme-switch.sh --theme rosepine --flavor main --accent pine --dry-run
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

The switcher runs six adapters in order. Each is independent; a failure in one does not block the others. All adapters are now theme-agnostic: install method, URLs, and palette tokens are read from the theme manifest at runtime.

### kde

Applies the full KDE/Qt visual stack. Behavior is driven by `kde_install_config`, `kvantum_config`, and `gtk_install_config` in the manifest.

**KDE install methods:**
- `catppuccin_script` — clones the repo and runs its numbered `install.sh` (Catppuccin only).
- `lookandfeel` — clones the repo, installs all top-level look-and-feel packages via `kpackagetool6`, then applies the selected one with `plasma-apply-lookandfeel` (used by Rose Pine and Tokyo Night).
- `plasma_package` — installs the whole repo as a single package.

**Common to all themes:**
- Applies `plasma-apply-colorscheme` and sets the lock screen greeter theme via `kwriteconfig6`.
- Installs and activates Kvantum if `kvantum_config.enabled` is true (Rose Pine skips this step).
- Installs GTK via `catppuccin_install_py` or `gtk_repo` (clone + `install.sh` or copy to `~/.themes`), then applies Flatpak GTK/icon overrides.
- Clones `catppuccin/papirus-folders` and sets accent folder colors only when `papirus_folder_code` is present in derived patterns (Catppuccin only).
- Writes `~/.config/gtk-3.0/settings.ini` from a template.
- Sets the icon theme to `Papirus-Dark` and the default terminal to `kitty` in `kdeglobals`.

### terminal

- Ensures `~/.config/kitty/kitty.conf` includes `./theme.conf`.
- Renders `~/.config/kitty/theme.conf` from a template with palette tokens for the selected flavor/accent.
- Renders `~/.config/starship.toml` from a template. The palette is always defined inline; no built-in Starship preset is required.

### editors

- Writes `~/.config/nvim/lua/colorscheme-flavor.lua` (gitignored) with a single line:
  ```lua
  return "<flavor>"
  ```
  The Neovim colorscheme plugin reads this file at startup. The tracked file `nvim/lua/plugins/colorscheme.lua` is not modified.

### cli

- Downloads the `bat` `.tmTheme` file from `bat_theme_config.repo` and rebuilds the bat cache.
- Writes or updates `~/.config/bat/config` to set `--theme`.
- Downloads the `btop` `.theme` file from `btop_theme_config.repo`.
- Writes or updates `~/.config/btop/btop.conf` to set `color_theme`.
- Sets `delta.syntax-theme` in the global git config.
- Renders `~/.config/fzf/colors.zsh` from a template for fzf color integration.

### apps

Runs for all themes. Steps that are not applicable to a theme are skipped gracefully.

- **Firefox**: Downloads the XPI from `firefox_config.repo` using `firefox_config.file_pattern` and installs it system-wide under `/usr/lib/firefox*/distribution/extensions/`. Skipped entirely when `firefox_config.method` is `"none"` (Tokyo Night). Manual activation is still required inside the Firefox Add-ons UI if the extension does not activate automatically.
- **TIDAL Hi-Fi**: Renders `~/.config/tidal-hifi/<theme>-<flavor>-<accent>.css` from a template and copies it to `~/.config/tidal-hifi/active.css`. Manual activation is required in tidal-hifi Settings > Theming (select `active.css` once; subsequent switches overwrite it automatically). Also writes a `.desktop` override with correct Wayland flags.
- **Rofi**: Downloads the adi1090x `type-2/style-9` launcher layout, generates `~/.config/rofi/colors/<theme>.rasi` from the manifest palette, patches `shared/colors.rasi` to import it, and renders `~/.config/rofi/config.rasi` from a template.

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

## Caveats

- SDDM and GRUB remain setup-managed and are not switched post-install.
- Firefox and tidal-hifi require manual activation in each app UI after the adapter installs or generates their theme files.
- The panel adapter sets `restart_pending: true` when it cannot reach the Panel Colorizer applet. The autostart script `scripts/apply-panel-colorizer.sh` handles reapplication on the next login session automatically; no manual intervention is needed unless the autostart is not registered.
- Rose Pine: Kvantum is skipped; the Qt widget style will remain as-is from the previous theme.
- Tokyo Night: No Firefox extension is available; the Firefox install step is skipped automatically.
- Tokyo Night: All accents resolve to the same `default` value. The `--accent` flag is accepted but has no visual effect beyond token substitution.
