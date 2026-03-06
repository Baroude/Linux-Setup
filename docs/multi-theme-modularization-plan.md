# Multi-Theme Modularization Plan (Session-First, Catppuccin-First)

## Summary
- Goal: Convert the current hardcoded Catppuccin Mocha/Mauve setup into a modular theming system that supports multiple palettes cleanly and enables post-install theme switching.
- Baseline decisions:
- Scope: Session-first for v1 (KDE session and app/tool theming only).
- Theme set: Catppuccin-first for v1 (flavors and accents), with architecture ready for Rose Pine and Tokyo Night adapters next.
- Config model: Hybrid manifests, templates, and per-theme special assets.
- Template rendering: Python `string.Template` with `${TOKEN}` delimiters. Python 3 is already available in base setup dependencies. This avoids the envsubst conflict with Starship's `$module` format string syntax.
- Success criteria:
- A user can run one switch command after installation and change theme consistently across supported layers without rerunning full setup.
- Setup can accept a default theme at install time.
- Theme logic is centralized with no duplicated full config trees per theme.

## Progress Update (2026-03-04)
- **Overall**: Core cutover is implemented in-repo. `setup.sh` now accepts theme args and calls `scripts/theme-switch.sh` for post-link apply.
- **Implemented**:
- Dotbot ownership split completed for theme-managed outputs (`kdeglobals`, `kvantum.kvconfig`, `starship.toml`, `gtk-3.0-settings.ini` removed from link ownership).
- `kitty.conf` static include model implemented (`include ./theme.conf`).
- Theme catalog + Catppuccin manifest + template set added under `themes/`.
- `theme-switch.sh` implemented with `--theme`, `--flavor`, `--accent`, `--list`, `--dry-run`, `--current`, `--non-interactive`.
- State model implemented at `~/.config/linux-setup/theme-state.json` with `status`, `completed_adapters`, `restart_pending`, `last_applied`.
- Adapters implemented for KDE/Kvantum/GTK/icons, terminal, editors, CLI, panel.
- Panel Colorizer duplication removed by extracting shared apply logic (`scripts/lib/panel-colorizer-apply.py`) and making autostart theme-state aware.
- Setup cleanup completed: direct setup-side theme application was removed so `scripts/theme-switch.sh` is now the single authoritative apply path during install (`Phase 14b`).
- README + `docs/themes.md` updated with modular theme usage and commands.
- **Validated so far**:
- Shell syntax checks passed for `setup.sh`, `theme-switch.sh`, panel scripts, and all `scripts/lib/*.sh`.
- `theme-switch.sh --list`, `--current` (no-state path), and full `--dry-run` execution path passed.
- **All PRs completed. Ready for final review.**

## In Scope (v1)
- Modularize theme application for:
- KDE look-and-feel and color scheme.
- KDE lock screen theme (`kscreenlockerrc`). This is user-space and switchable via `kwriteconfig6`; distinct from the SDDM display manager (system-space, out of scope).
- Kvantum theme selection (via `kvantummanager --set`, not a template).
- GTK theme/cursor names and Flatpak GTK override.
- Papirus folder accent selection.
- Top bar widget accent colors (implemented via Panel Colorizer). Two distinct subsystems — see Implementation Plan phase 4.
- Kitty colors (via a generated `theme.conf` include, not replacing the static `kitty.conf`).
- Starship palette selection.
- Neovim Catppuccin flavor.
- CLI tool theming currently hardcoded in setup (`bat`, `btop`, `delta`) where Catppuccin variants exist.
- Add post-install switch workflow with persisted active-theme state.
- Update install flow and docs to use the new model.

## Out of Scope (v1)
- Live switching of SDDM display manager and GRUB themes (system-level, require root and package replacement).
- Firefox extension theme switching (requires browser automation; remains manual).
- tidal-hifi CSS theme switching (requires manual selection in app settings UI; the CSS file is templatable but the app does not expose a CLI switch).
- Full Rose Pine/Tokyo Night implementation (placeholder catalog entries only).
- Replacing existing panel layout architecture beyond color/preset modularization.
- Full non-Catppuccin fallback theming for every third-party tool in v1.

## Public Interfaces and Contract Changes
- New command interface:
- `scripts/theme-switch.sh` as the single entrypoint for applying a theme post-install.
- Supported flags in v1:
- `--theme <name>`
- `--flavor <name>` (for Catppuccin)
- `--accent <name>`
- `--list`
- `--dry-run`
- `--current`
- `--non-interactive`
- New setup interface:
- `setup.sh` accepts `--theme`, `--flavor`, `--accent` and applies that selection during install.
- New config interfaces:
- `themes/catalog.yaml` listing supported themes, valid flavors/accents, and component capability map.
- `themes/manifests/<theme>.yaml` with normalized tokens and adapter-specific mappings. See manifest data model below.
- `themes/templates/` for renderable config templates (rendered with Python `string.Template`).
- `themes/templates/panel-colorizer-global.json.tpl` for Panel Colorizer structural settings (replaces the discarded per-flavor/accent static file approach).
- New runtime state interface:
- `~/.config/linux-setup/theme-state.json` with schema:
  ```json
  {
    "theme": "catppuccin",
    "flavor": "mocha",
    "accent": "mauve",
    "status": "applied|partial|failed",
    "completed_adapters": ["kde", "kvantum", "gtk", "icons", "panel", "terminal", "editors", "cli"],
    "restart_pending": false,
    "last_applied": "<ISO8601>"
  }
  ```
- `--current` reports status, completed adapters, and warns if a session restart is pending.
- State is always persisted after any apply attempt, regardless of outcome. Full success writes `status: applied`. Partial failure writes `status: partial` with `completed_adapters` listing which adapters succeeded. A hard abort before any adapter runs writes `status: failed`.
- Dotbot contract update (required before PR 2 — see Delivery Breakdown):
- Remove theme-managed links from `install.conf.yaml` and `install-plasma.conf.yaml` so `./install` no longer overwrites active switched theme files.
- Files to reclassify as theme-managed (remove from dotbot links): `kdeglobals`, `kvantum.kvconfig`, `starship.toml`, `gtk-3.0-settings.ini`.
- Exception: `kitty.conf` remains dotbot-linked. The theme adapter writes `~/.config/kitty/theme.conf` and adds a one-time `include ./theme.conf` to the static `kitty.conf`. Only `theme.conf` is theme-managed. The include insertion is idempotent: the adapter checks for an existing `include ./theme.conf` line before writing and skips if already present.

## Manifest Data Model
The Catppuccin manifest is structured as follows — not as 56 flat token sets:

- **Flavor token sets (4 entries)**: One per flavor (Latte, Frappe, Macchiato, Mocha). Each entry contains the full 26-color Catppuccin palette for that flavor (base, mantle, crust, surface0–2, overlay0–2, subtext0–1, text, rosewater, flamingo, pink, mauve, red, maroon, peach, yellow, green, teal, sky, sapphire, blue, lavender).
- **Accent keys (14 entries)**: Each accent name maps to a palette slot key (e.g. `mauve → mauve`, `blue → blue`, `pink → pink`). At apply time, the active accent hex value is `flavors[flavor][accent_key]`.
- **Derived component identifiers**: Expressed as lookup tables keyed by `(flavor, accent)` where the naming pattern is non-trivial, or as format strings where naming is regular (e.g. `kde_scheme: "Catppuccin{Flavor}{Accent}"`, `gtk_theme: "catppuccin-{flavor}-{accent}-standard+default"`). These are not duplicated 56 times.
- **Widget→palette-slot mapping**: Fixed semantic slots (e.g. `pager: lavender`, `clock: accent`, `weather: blue`, `appmenu: green`). At apply time, the slot name resolves to a hex via the active flavor token set, with `accent` resolving to the selected accent color.

## Target Repository Structure
- `themes/catalog.yaml`
- `themes/manifests/catppuccin.yaml`
- `themes/templates/kitty-theme.conf.tpl` (rendered to `~/.config/kitty/theme.conf`)
- `themes/templates/starship.toml.tpl`
- `themes/templates/nvim-colorscheme.lua.tpl` or equivalent parameterized source for current plugin config
- `themes/templates/gtk-3.0-settings.ini.tpl`
- `themes/templates/panel-colorizer-global.json.tpl` (structural settings only; widget colors resolved at runtime)
- `scripts/theme-switch.sh`
- `scripts/lib/theme-common.sh`
- `scripts/lib/theme-apply-kde.sh`
- `scripts/lib/theme-apply-terminal.sh`
- `scripts/lib/theme-apply-editors.sh`
- `scripts/lib/theme-apply-panel.sh`
- `docs/themes.md` (new operational doc)

Note: `themes/templates/kvantum.kvconfig.tpl` is intentionally absent. Kvantum is managed via `kvantummanager --set <name>` by the adapter. `themes/assets/panel-colorizer/catppuccin/<flavor>/<accent>.json` (56 static files) is intentionally absent; replaced by the single global template plus runtime token resolution.

## Implementation Plan
1. Baseline and extraction phase:
- Inventory every hardcoded theme token in `setup.sh`, `scripts/configure-dock.sh`, `scripts/apply-panel-colorizer.sh`, `kitty/kitty.conf`, `starship.toml`, `nvim/lua/plugins/colorscheme.lua`, `gtk/gtk-3.0-settings.ini`, and `kvantum/kvantum.kvconfig`.
- Define canonical token names shared across components (base, mantle, crust, text, primary accent, secondary accents).
- Create a migration matrix mapping old hardcoded values to manifest fields.

2. Theme data model phase:
- Create `themes/catalog.yaml` with:
- Supported themes list (initially `catppuccin`).
- Valid Catppuccin flavors and accents.
- Per-component support flags.
- Create `themes/manifests/catppuccin.yaml` using the data model defined above:
- 4 flavor token sets (26 colors each).
- 14 accent-name-to-palette-slot entries.
- Derived component identifier patterns for KDE scheme/look-and-feel, Kvantum theme name, GTK theme/cursor names, Papirus folder codes, Neovim flavor value, Starship palette reference, CLI theme identifiers.
- Widget→palette-slot mapping for panel adapter.
- Validate manifest semantics at runtime in `theme-switch.sh` before any apply step.

3. Rendering and apply engine phase:
- Implement shared library routines for:
- Argument parsing and validation.
- Manifest loading and normalization.
- Template rendering via Python `string.Template` with `${TOKEN}` delimiters.
- Ordered apply execution with per-adapter result tracking.
- Rollback guardrails. Define rollback semantics here even if full implementation is in PR 5.
- Define strict apply order to avoid inconsistent state:
- Theme asset install/check.
- KDE/Qt/GTK layer apply.
- Terminal/shell/editor layer apply.
- Panel Colorizer apply.
- Session reload calls.
- Theme selection precedence (resolved once at startup, before any adapter runs): CLI args override saved state; saved state overrides built-in defaults. If no args and no state file, defaults are `catppuccin/mocha/mauve`.
- State persistence rule: always write state after any apply attempt. Full success → `status: applied`. One or more adapter failures → `status: partial` + `completed_adapters`. Validation or pre-flight failure → `status: failed` (no adapters ran, selection fields still written so `--current` is informative).
- Rollback semantics: there is no automatic undo of already-applied adapters. The system is best-effort forward: each adapter is atomic within itself (write temp file, verify, then move into place for template-rendered files; imperative calls like `plasma-apply-colorscheme` are not reversible). On partial failure, `--current` shows which adapters completed so the user can re-run to finish. Full rollback to a prior selection is done by re-running `theme-switch.sh` with the old flavor/accent.
- Dotbot reclassification (prerequisite, must land before adapters run):
- Remove `kdeglobals` from `install-plasma.conf.yaml`.
- Remove `kvantum.kvconfig`, `starship.toml`, `gtk-3.0-settings.ini` from `install.conf.yaml`.
- Add `include ./theme.conf` to `kitty/kitty.conf` (one-time static edit; `kitty.conf` stays dotbot-linked).

4. Component adapter phase (Catppuccin-first):
- KDE adapter:
- Parameterize `catppuccin/kde` installer arguments for flavor/accent.
- Apply matching Plasma color scheme/look-and-feel names.
- Apply KDE lock screen theme via `kwriteconfig6 --file kscreenlockerrc --group Greeter --key Theme <name>`.
- Kvantum adapter:
- Call `kvantummanager --set <kvantum_theme_name>` from manifest. No template file.
- Set widget style: `kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum`.
- GTK adapter:
- Apply matching theme + cursor naming and Flatpak GTK override value.
- Icons adapter:
- Apply Papirus folder accent corresponding to selected accent.
- Panel adapter (two distinct subsystems — address both):
- **Global Panel Colorizer settings**: render `panel-colorizer-global.json.tpl` with flavor base/surface tokens; apply via existing D-Bus mechanism.
- **Per-widget accent color map**: at apply time, resolve the widget→palette-slot mapping from the manifest against the active flavor's token set to produce per-widget hex values; inject into the D-Bus config call in `apply-panel-colorizer.sh`.
- Deduplicate: the Python block that builds the widget color map is currently duplicated between `configure-dock.sh` and `apply-panel-colorizer.sh`; extract into a shared library or data file consumed by both.
- Update the `apply-panel-colorizer.sh` autostart to read the active theme state and resolve colors dynamically, so login re-application does not revert to hardcoded Mocha. This update must land in this PR.
- Terminal/shell/editor adapters:
- Render Kitty theme file to `~/.config/kitty/theme.conf` from tokens.
- Render Starship `starship.toml` from template (uses Python `string.Template` to avoid conflict with Starship's `$module` syntax).
- Set Neovim Catppuccin flavor dynamically.
- CLI adapter:
- Set `bat` theme name for selected Catppuccin flavor.
- Update `btop.conf` theme key with a targeted replacement (not a full overwrite; the file may contain user customizations).
- Set `delta.syntax-theme` via `git config --global delta.syntax-theme "<name>"` (lives in `~/.gitconfig`, not a template file).

5. Installer integration phase:
- Update `setup.sh` to parse and pass theme arguments to the shared theme apply flow.
- Split setup responsibilities:
- Installation of dependencies/assets.
- Final call to modular theme apply.
- Ensure idempotent re-runs keep selected theme stable and do not revert to Mocha/Mauve defaults unless explicitly requested.

6. Dotbot and file ownership phase:
- Note: the dotbot reclassification of theme-managed files (kdeglobals, kvantum.kvconfig, starship.toml, gtk-3.0-settings.ini) is done in phase 3 as a prerequisite for adapters. This phase covers remaining documentation and verification.
- Confirm no theme-managed files remain in dotbot link lists.
- Keep non-theme links unchanged.

7. UX and operations phase:
- Add `--list` output showing valid themes/flavors/accents from catalog.
- Add `--dry-run` output showing exact operations and affected files/commands.
- Add `--current` output showing active selection, completed adapters, restart-pending status.
- Add clear error messages for unsupported combinations.
- Persist active selection in user state file.

8. Documentation phase:
- Rewrite `README.md` sections that currently claim fixed Mocha/Mauve.
- Add `docs/themes.md` with:
- Supported combinations.
- Install-time theme selection.
- Post-install switch flow.
- Known caveats and restart requirements.
- Note that tidal-hifi CSS is template-derivable but not auto-switched; manual selection required in app.
- Explicitly document that SDDM/GRUB switching is deferred to phase 2.
- Document that the Firefox theme and tidal-hifi CSS remain manual-only.

9. Forward-compatibility phase (planned, not implemented in v1):
- Add placeholder catalog entries and adapter stubs for Rose Pine and Tokyo Night.
- Define per-component fallback policy when a target family lacks an exact equivalent.

## Known Caveats
- First-login race: if `theme-switch.sh` is run before the first KDE login completes, the Panel Colorizer applet does not yet exist. The panel adapter must detect this (check for applet presence via D-Bus) and skip gracefully, logging a pending action to state.
- Panel persistence model: autostart `apply-panel-colorizer.sh` performs live re-application only (`write_disk=0`) by design. Disk persistence writes happen in `configure-dock.sh` (`write_disk=1`). This avoids repeated appletsrc churn on every login but means a manual destructive reset of Plasma applet config is not auto-repersisted by autostart alone.
- KDE restart requirements: `plasma-apply-colorscheme` and `plasma-apply-lookandfeel` update the live session; `kdeglobals` changes for already-running Qt apps may require `kquitapp6 plasmashell && kstart6 plasmashell`. The `restart_pending` state field tracks when this is needed.
- catppuccin-vibes SVG icons are flavor-invariant; they do not change per flavor/accent. For non-Catppuccin themes in v2, icon sets will need separate handling.

## Testing and Validation Scenarios
- Manifest validation:
- Invalid theme name rejects with actionable message.
- Invalid flavor/accent rejects with list of valid options.
- Dry-run behavior:
- `--dry-run` produces full operation plan with no writes.
- Install-time behavior:
- Fresh install with explicit Catppuccin flavor/accent applies selection end-to-end.
- Re-run install preserves current selected theme unless overridden by args.
- Post-install switch behavior:
- Switch between two Catppuccin accents and verify all supported layers update.
- Switch between Catppuccin flavors and verify all supported layers update.
- Idempotency:
- Running same switch twice yields no drift and no failures.
- Failure handling:
- Simulate one adapter failure and verify partial-apply rollback behavior or explicit failure report with remediation.
- `completed_adapters` in state file reflects which adapters succeeded.
- Dotbot coexistence:
- Running `./install` after a switch does not revert theme-managed files.
- Running `./install -c install-plasma.conf.yaml` does not revert kdeglobals.
- KDE session checks:
- Verify expected `kdeglobals` values, Kvantum active theme, GTK theme names, KDE lock screen theme, and panel colorizer applied colors.
- Tool checks:
- Verify Kitty, Starship, Neovim, bat, btop, and delta reflect chosen flavor/accent mappings.

## Acceptance Criteria
- Theme selection is no longer hardcoded in `setup.sh`.
- `theme-switch.sh` can switch supported theme variants post-install without full reinstall.
- Dotbot no longer overwrites theme-managed outputs.
- The lock screen greeter theme matches the active KDE flavor/accent selection.
- README reflects modular theme architecture and operational commands.
- The system remains idempotent and stable on reruns.

## Assumptions and Defaults
- Default theme in v1 remains `catppuccin`.
- Default Catppuccin flavor/accent remain current behavior-compatible values unless user overrides.
- Template rendering engine: Python `string.Template` with `${TOKEN}` delimiters.
- System-level theming (SDDM/GRUB) is intentionally excluded from v1 switching.
- Firefox and tidal-hifi remain manual-only due to no CLI switch mechanism.
- Existing unrelated local changes (`dotbot`, `.claude/`) are not part of this plan's implementation scope.
- Primary target environment remains Debian 13 + KDE Plasma 6 on Wayland.

## Delivery Breakdown (PR sequencing)
- PR 1: Theme data model and switcher scaffolding (`catalog`, manifest with correct data model, parser, validation, dry-run, `--list`, `--current`) + dotbot reclassification of theme-managed files (prerequisite for all adapter PRs). **Status: Completed**
- PR 2: Catppuccin adapters for KDE (including kscreenlockerrc)/Kvantum/GTK/icons/panel (including widget color map deduplication and autostart migration to theme-aware apply). **Status: Completed**
- PR 3: Terminal/shell/editor/CLI adapters (Kitty via `theme.conf` include, Starship, Neovim, bat, btop targeted-key update, delta via `git config --global`) and setup.sh argument integration. **Status: Completed (runtime validation confirmed on 2026-03-04)**
- PR 4: Docs only — README rewrite and `docs/themes.md`. **Status: Completed**
- PR 5: Hardening pass with failure handling, partial-apply rollback, `completed_adapters` state, first-login race guard, and validation script outputs. **Status: Completed**
