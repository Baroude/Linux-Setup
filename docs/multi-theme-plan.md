# Multi-Theme Support — Implementation Plan

Themes to add: **Rose Pine** and **Tokyo Night**, alongside existing Catppuccin.

---

## Problem: every adapter is catppuccin-hardcoded

| Concern | Location |
|---|---|
| KDE install script | `theme-apply-kde.sh` — clones catppuccin/kde, runs `./install.sh $flavor_idx $accent_idx 1` |
| Kvantum + GTK repos | same file — catppuccin/kvantum + catppuccin/gtk install.py |
| bat / btop download URLs | `theme-apply-cli.sh` |
| Firefox XPI URL | `theme-apply-apps.sh` |
| Kitty + fzf template tokens | `kitty-theme.conf.tpl`, `fzf-colors.zsh.tpl` — use catppuccin palette key names (`ROSEWATER`, `SURFACE1`, `SKY`, `LAVENDER`, `SUBTEXT0`, `MANTLE`, …) |
| Starship palette preset | `starship.toml.tpl` — `palette = '$STARSHIP_PALETTE_NAME'` references a Starship built-in preset. Catppuccin and Rose Pine have built-ins; Tokyo Night does not. |

---

## Phase 1 — Abstract the manifest schema and adapters

### 1a. Add install config sections to `catppuccin.json`

Replace hardcoded repo URLs and install logic in shell scripts with structured config read from the manifest:

```json
"kde_install_config": {
  "method": "catppuccin_script",
  "repo":   "https://github.com/catppuccin/kde"
},
"kvantum_config": {
  "enabled": true,
  "method":  "catppuccin_repo",
  "repo":    "https://github.com/catppuccin/kvantum"
},
"gtk_install_config": {
  "method":  "catppuccin_install_py",
  "version": "v1.0.3"
},
"bat_theme_config": {
  "repo":         "https://github.com/catppuccin/bat",
  "file_pattern": "Catppuccin ${FlavorTitle}.tmTheme"
},
"btop_theme_config": {
  "repo":         "https://github.com/catppuccin/btop",
  "file_pattern": "catppuccin_${flavor}.theme"
},
"firefox_config": {
  "method":       "github_xpi",
  "repo":         "catppuccin/firefox",
  "file_pattern": "catppuccin_${flavor}_${accent}.xpi"
}
```

### 1b. Fix `theme_build_context_json` in `theme-common.sh`

`kde_installer_index` is currently read unconditionally — a missing key crashes the context build for non-catppuccin themes. Change to `.get("kde_installer_index", {})`.

### 1c. Refactor `theme-apply-kde.sh`

- Remove the `if [[ "$theme" != "catppuccin" ]] ... return 1` guard.
- Read `kde_install_config.method` from context and dispatch:
  - `catppuccin_script` — current behavior (clone + `./install.sh $flavor_idx $accent_idx 1`)
  - `lookandfeel` — clone repo, copy theme files, call `plasma-apply-lookandfeel`
  - `plasma_package` — `kpackagetool6 --install`
- Same dispatch pattern for Kvantum (`kvantum_config.method`) and GTK (`gtk_install_config.method`).

### 1d. Refactor `theme-apply-cli.sh`

Read bat and btop repo URLs and file patterns from the manifest install config instead of hardcoding.

### 1e. Refactor `theme-apply-apps.sh`

Read Firefox install method and URL from manifest `firefox_config`. Skip gracefully if `firefox_config` is absent or `method` is `"none"`.

### 1f. Fix the Starship template

Currently relies on Starship built-in named presets (`catppuccin_mocha`, `rose_pine_main`, …). Tokyo Night has no built-in preset.

Fix: always define the palette **inline** in the rendered `starship.toml`, removing the dependency on built-in presets entirely:

```toml
palette = '${STARSHIP_PALETTE_NAME}'

[palettes.${STARSHIP_PALETTE_NAME}]
rosewater = '${ROSEWATER}'
flamingo  = '${FLAMINGO}'
base      = '${BASE}'
# ... all palette tokens
```

This makes the template self-contained for any theme.

### 1g. Fix kitty and fzf templates — palette key aliases

Rose Pine palette key names (`love`, `foam`, `iris`, `overlay`, `muted`, `subtle`, …) differ from catppuccin (`rosewater`, `sky`, `lavender`, `surface0`, `subtext0`, `mantle`, …).

Solution: keep templates unchanged. Each manifest's flavor palette includes **catppuccin-compatible aliases** for every token the templates reference. For example, in Rose Pine `main`:

```json
"rosewater": "#ebbcba",   // alias for rose
"sky":       "#9ccfd8",   // alias for foam
"lavender":  "#c4a7e7",   // alias for iris
"surface0":  "#26233a",   // alias for overlay
"surface1":  "#2a273f",   // alias for surface
"surface2":  "#393552",
"subtext0":  "#6e6a86",   // alias for muted
"subtext1":  "#908caa",   // alias for subtle
"mantle":    "#191724"    // alias for base (darkest bg)
```

The rendering engine uppercases all palette keys into tokens — aliases flow through automatically with no template changes.

---

## Phase 2 — Rose Pine

**Variants**: `main`, `moon`, `dawn` (dawn is light)
**Accents**: `love`, `gold`, `rose`, `pine`, `foam`, `iris`

### Component sources

| Component | Source |
|---|---|
| KDE | `rose-pine/kde` — `plasma-apply-lookandfeel` (no numbered installer script) |
| Kvantum | No official theme → skip (`kvantum_config.enabled: false`), leave current style |
| GTK | `rose-pine/gtk` |
| bat | `rose-pine/bat` |
| btop | community theme |
| kitty | existing template + palette aliases (Phase 1g) |
| Starship | inline palette (Phase 1f); native key names used in palette block |
| Firefox | Rose Pine Firefox extension (URL per variant) |
| Rofi | Re-use adi1090x layout; swap color file to Rose Pine equivalent |

### Deliverables

- `themes/manifests/rosepine.json` — full palette for all 3 variants + 6 accents + install configs + catppuccin-compatible aliases
- `themes/catalog.json` — enable rosepine entry (remove `"supported": false`)

---

## Phase 3 — Tokyo Night

**Variants**: `night`, `storm`, `moon`, `day`
**Accents**: no accent concept → use `["default"]` sentinel; accent-specific steps skipped by adapters

### Component sources

| Component | Source |
|---|---|
| KDE | community port (tokyo-night-kde) — `lookandfeel` method |
| Kvantum | community Kvantum theme |
| GTK | Tokyonight-GTK-Theme |
| bat | official `tokyo-night` bat theme |
| btop | community `.theme` file |
| kitty | existing template + palette aliases |
| Starship | inline palette only (no built-in preset) — covered by Phase 1f |
| Firefox | no official extension → `firefox_config.method: "none"` (skip) |
| Rofi | Re-use adi1090x layout; swap color file |

### Deliverables

- `themes/manifests/tokyonight.json` — full palette for all 4 variants + install configs + catppuccin-compatible aliases
- `themes/catalog.json` — enable tokyonight entry

---

## Phase 4 — Documentation

Update `docs/themes.md`:

- Rose Pine section: variants, accents, note that Kvantum is skipped
- Tokyo Night section: variants, note no accent selection, note no Firefox extension
- Update adapter table to reflect that all adapters are now theme-agnostic
- Update `--list` output example to show all three themes

---

## Execution order

```
Phase 1  (adapter abstraction)
    └── must land first — Phases 2 & 3 depend on the new dispatch logic

Phase 2 + Phase 3  (parallel)
    └── independent manifest + catalog work once Phase 1 is in place

Phase 4  (docs)
    └── after Phase 2 + 3 are validated
```

---

## Open questions

1. **Rose Pine Kvantum fallback** — skip Kvantum entirely, or set a neutral fallback style (e.g. `kvantummanager --set KvantumDark`) when `kvantum_config.enabled` is false?
2. **Tokyo Night accent sentinel** — use `["default"]` in the catalog, or offer a curated subset of palette colors as selectable accents (e.g. `blue`, `magenta`, `green`, `orange`, `red`, `cyan`)?
3. **Rofi color files** — the adi1090x layout ships a catppuccin color file. For Rose Pine and Tokyo Night: (a) download community color files if available, or (b) generate them from the manifest palette via a template. Option (b) is more robust and avoids external dependencies.
4. **`doctor.sh`** — should be updated to skip Kvantum checks when `kvantum_config.enabled` is false for the active theme.
