# Theme Switching

This repository uses a modular theme runtime for user-space theming.

## Supported Theme Family (v1)

- `catppuccin`
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

Show current applied state:

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

## Runtime State

The switcher persists state at:

- `~/.config/linux-setup/theme-state.json`

Schema fields used in v1:

- `theme`, `flavor`, `accent`
- `status`: `applied | partial | failed`
- `completed_adapters`: list of successful adapters
- `restart_pending`: boolean
- `last_applied`: ISO8601 timestamp

## v1 Caveats

- SDDM and GRUB remain setup-managed and are not switched post-install.
- Firefox extension install, tidal-hifi CSS generation, and rofi theming from the official `catppuccin/rofi` repository are handled by the `apps` adapter.
- Firefox and tidal-hifi may still require manual activation in each app UI after files are installed/generated.
- Panel Colorizer apply requires a running Plasma session. If the applet is not ready yet, rerun:

```bash
bash scripts/apply-panel-colorizer.sh
```
