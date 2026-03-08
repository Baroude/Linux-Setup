# Design: Rose Pine Kvantum Support

**Date:** 2026-03-08
**Branch:** feat/multi-theme

## Problem

The Rose Pine manifest has `kvantum_config.enabled: false` because the theme was assumed to have no official Kvantum support. The official `rose-pine/kvantum` repo now exists and ships prebuilt tarballs for every flavor+accent combination.

## Repo Structure

`https://github.com/rose-pine/kvantum` — `dist/` contains:
- `rose-pine-${accent}.tar.gz` — main flavor (no "main" in filename)
- `rose-pine-moon-${accent}.tar.gz`
- `rose-pine-dawn-${accent}.tar.gz`

Each tarball extracts a single directory named after the file (minus `.tar.gz`), containing `.kvconfig` and `.svg`.

## Design

### New Kvantum method: `tarball_release`

A generic method added to `_kde_install_kvantum` in `theme-apply-kde.sh`. Any theme manifest can use it by setting:

```json
"kvantum_config": {
  "enabled": true,
  "method": "tarball_release",
  "base_url": "<raw download base>",
  "file_pattern": "<filename with ${flavor}/${accent} tokens>",
  "files_by_flavor": { "<flavor>": "<override pattern>" }
}
```

The adapter downloads `{base_url}/{resolved_file}`, removes the old theme dir from `~/.config/Kvantum/`, extracts the tarball there, then runs the shared activation (write `kvantum.kvconfig`, set `widgetStyle kvantum`).

### Context builder changes (`theme-common.sh`)

For any `kvantum_config` with `file_pattern`, the builder resolves:
- `resolved_file` — `files_by_flavor[flavor]` override if present, else `file_pattern`, with `${flavor}`/`${accent}` substituted
- `resolved_theme` — `resolved_file` with `.tar.gz` stripped (used as the Kvantum theme/dir name)

This mirrors the existing `bat_theme_config`/`btop_theme_config` resolution pattern.

### Manifest changes (`rosepine.json`)

```json
"kvantum_config": {
  "enabled": true,
  "method": "tarball_release",
  "base_url": "https://raw.githubusercontent.com/rose-pine/kvantum/master/dist",
  "file_pattern": "rose-pine-${flavor}-${accent}.tar.gz",
  "files_by_flavor": {
    "main": "rose-pine-${accent}.tar.gz"
  }
}
```

`derived_patterns.kvantum_theme` is removed (was a static placeholder `"RosePine"`). The adapter reads `kvantum_config.resolved_theme` instead when using `tarball_release`.

### Docs update (`docs/themes.md`)

Remove "Kvantum skipped" caveat for Rose Pine. Note that accents are fully supported.

## Files Changed

| File | Change |
|---|---|
| `themes/manifests/rosepine.json` | Enable Kvantum, add tarball_release config, remove stale kvantum_theme derived pattern |
| `scripts/lib/theme-common.sh` | Resolve `kvantum_config.resolved_file` and `resolved_theme` in context builder |
| `scripts/lib/theme-apply-kde.sh` | Add `tarball_release` case to `_kde_install_kvantum` |
| `docs/themes.md` | Update Rose Pine Kvantum caveat |
