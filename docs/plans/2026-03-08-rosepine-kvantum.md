# Rose Pine Kvantum tarball_release Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a generic `tarball_release` Kvantum install method and wire it up for Rose Pine, which ships prebuilt per-flavor+accent tarballs in `dist/` of `rose-pine/kvantum`.

**Architecture:** Three layers change in order — (1) context builder resolves the tarball filename + theme dir name into `kvantum_config.resolved_file` / `resolved_theme`; (2) KDE adapter gains a `tarball_release` case that downloads/extracts the tarball and overrides the local `kvantum_theme` before the shared activation code runs; (3) manifest flips Rose Pine Kvantum on. No new files; no new abstractions.

**Tech Stack:** Bash, Python 3 (stdlib only), `curl`, `tar`, KDE CLI tools (`kwriteconfig6`).

---

## Background: How Kvantum install works today

`_kde_install_kvantum` in `scripts/lib/theme-apply-kde.sh`:

1. Reads `kvantum_config.enabled` — bails early if false.
2. Reads `kvantum_config.method` and `kvantum_config.repo` + `derived.kvantum_theme` at the top.
3. Dispatches on method (`catppuccin_repo`, `kvantum_repo`).
4. After the case, activates: writes `~/.config/Kvantum/kvantum.kvconfig` and sets `widgetStyle kvantum`.

**Problem with current structure:** `kvantum_repo` is read unconditionally at the top, so adding a method that uses a different key (e.g. `base_url`) would cause `theme_context_get "kvantum_config.repo"` to fail with a KeyError for Rose Pine (no `repo` key). Same issue for `derived.kvantum_theme` if we remove it from the manifest.

**Fix:** Move per-method field reads into their case branches. The shared activation at the bottom only needs local `kvantum_theme`.

---

## Task 1: Extend context builder — resolve kvantum_config.resolved_file + resolved_theme

**Files:**
- Modify: `scripts/lib/theme-common.sh` (the `theme_build_context_json` Python heredoc, around line 204)

The builder already does this for `bat_theme_config` and `btop_theme_config`. Replicate the pattern for `kvantum_config`.

**Step 1: Locate the exact lines to change**

In `theme-common.sh`, find:
```python
bat_cfg  = resolve_config(manifest.get("bat_theme_config", {}))
btop_cfg = resolve_config(manifest.get("btop_theme_config", {}))
```
and the block below it:
```python
for cfg in (bat_cfg, btop_cfg):
    if cfg:
        override = cfg.get("files_by_flavor", {}).get(flavor)
        cfg["resolved_file"] = override if override else cfg.get("file_pattern", "")
```
and the context dict entry:
```python
"kvantum_config": resolve_config(manifest.get("kvantum_config", {"enabled": False})),
```

**Step 2: Apply the change**

Replace:
```python
bat_cfg  = resolve_config(manifest.get("bat_theme_config", {}))
btop_cfg = resolve_config(manifest.get("btop_theme_config", {}))

# Resolve per-flavor file overrides for bat and btop.
# files_by_flavor[flavor] takes precedence over the generic file_pattern.
for cfg in (bat_cfg, btop_cfg):
    if cfg:
        override = cfg.get("files_by_flavor", {}).get(flavor)
        cfg["resolved_file"] = override if override else cfg.get("file_pattern", "")
```
with:
```python
bat_cfg     = resolve_config(manifest.get("bat_theme_config", {}))
btop_cfg    = resolve_config(manifest.get("btop_theme_config", {}))
kvantum_cfg = resolve_config(manifest.get("kvantum_config", {"enabled": False}))

# Resolve per-flavor file overrides for bat, btop, and kvantum.
# files_by_flavor[flavor] takes precedence over the generic file_pattern.
for cfg in (bat_cfg, btop_cfg):
    if cfg:
        override = cfg.get("files_by_flavor", {}).get(flavor)
        cfg["resolved_file"] = override if override else cfg.get("file_pattern", "")

# kvantum: also derive resolved_theme (directory name = filename minus .tar.gz)
if kvantum_cfg and kvantum_cfg.get("file_pattern"):
    override = kvantum_cfg.get("files_by_flavor", {}).get(flavor)
    raw = Template(override if override else kvantum_cfg.get("file_pattern", "")).safe_substitute(params)
    kvantum_cfg["resolved_file"] = raw
    kvantum_cfg["resolved_theme"] = raw.removesuffix(".tar.gz")
```

Also replace the context dict entry:
```python
"kvantum_config": resolve_config(manifest.get("kvantum_config", {"enabled": False})),
```
with:
```python
"kvantum_config": kvantum_cfg,
```

**Step 3: Verify with a dry-run context dump**

```bash
cd /path/to/Linux-Setup
THEME_CONTEXT_JSON="$(bash -c '
  source scripts/lib/theme-common.sh
  theme_build_context_json rosepine moon iris
')"
echo "$THEME_CONTEXT_JSON" | python3 -c "
import json,sys
ctx=json.load(sys.stdin)
kv=ctx['kvantum_config']
print('enabled:', kv['enabled'])
print('method:', kv['method'])
print('resolved_file:', kv.get('resolved_file'))
print('resolved_theme:', kv.get('resolved_theme'))
"
```
Expected output (after Task 3 updates the manifest):
```
enabled: true
method: tarball_release
resolved_file: rose-pine-moon-iris.tar.gz
resolved_theme: rose-pine-moon-iris
```

Also verify main flavor:
```bash
THEME_CONTEXT_JSON="$(bash -c '
  source scripts/lib/theme-common.sh
  theme_build_context_json rosepine main love
')"
echo "$THEME_CONTEXT_JSON" | python3 -c "
import json,sys
ctx=json.load(sys.stdin)
kv=ctx['kvantum_config']
print('resolved_file:', kv.get('resolved_file'))
print('resolved_theme:', kv.get('resolved_theme'))
"
```
Expected:
```
resolved_file: rose-pine-love.tar.gz
resolved_theme: rose-pine-love
```

**Step 4: Commit**

```bash
git add scripts/lib/theme-common.sh
git commit -m "feat(theme): resolve kvantum_config.resolved_file and resolved_theme in context builder"
```

---

## Task 2: Refactor _kde_install_kvantum + add tarball_release case

**Files:**
- Modify: `scripts/lib/theme-apply-kde.sh` (`_kde_install_kvantum`, lines 77–132)

**Step 1: Understand the current structure**

The function currently reads `kvantum_repo` and `kvantum_theme` unconditionally at the top (lines 86–89). These fetches will fail for any method that doesn't define those manifest keys. Refactor: move them into the cases that need them.

**Step 2: Replace the function**

Replace the entire `_kde_install_kvantum` function (lines 77–132) with:

```bash
_kde_install_kvantum() {
  local kvantum_enabled
  kvantum_enabled="$(theme_context_get "kvantum_config.enabled")"

  if [[ "$kvantum_enabled" != "true" ]]; then
    theme_info "Kvantum disabled for this theme; skipping"
    return 0
  fi

  local kvantum_method kvantum_theme
  kvantum_method="$(theme_context_get "kvantum_config.method")"
  # kvantum_theme is read here as default; tarball_release overrides it below
  kvantum_theme="$(theme_context_get "derived.kvantum_theme" 2>/dev/null)" || kvantum_theme=""

  case "$kvantum_method" in
    catppuccin_repo)
      local kvantum_repo
      kvantum_repo="$(theme_context_get "kvantum_config.repo")"
      theme_clone_fresh /tmp/theme-kvantum "$kvantum_repo"
      theme_run "create kvantum dir" mkdir -p "$HOME/.config/Kvantum"
      theme_run "remove previous kvantum theme dir" rm -rf "$HOME/.config/Kvantum/${kvantum_theme}"
      theme_run "install kvantum theme files" cp -r "/tmp/theme-kvantum/themes/${kvantum_theme}" "$HOME/.config/Kvantum/"
      [[ "${THEME_DRY_RUN}" == "1" ]] || rm -rf /tmp/theme-kvantum
      ;;

    kvantum_repo)
      local kvantum_repo
      kvantum_repo="$(theme_context_get "kvantum_config.repo")"
      # Generic: clone repo, find directory matching kvantum_theme name, copy it
      theme_clone_fresh /tmp/theme-kvantum "$kvantum_repo"
      theme_run "create kvantum dir" mkdir -p "$HOME/.config/Kvantum"
      theme_run "remove previous kvantum theme dir" rm -rf "$HOME/.config/Kvantum/${kvantum_theme}"
      if [[ "${THEME_DRY_RUN}" == "1" ]]; then
        echo "[dry-run] find and copy kvantum theme dir ${kvantum_theme}"
      else
        local src_dir
        src_dir="$(find /tmp/theme-kvantum -maxdepth 3 -type d -name "${kvantum_theme}" | head -1)"
        if [[ -n "$src_dir" ]]; then
          cp -r "$src_dir" "$HOME/.config/Kvantum/"
        else
          theme_warn "Kvantum theme dir '${kvantum_theme}' not found in repo; skipping"
        fi
        rm -rf /tmp/theme-kvantum
      fi
      ;;

    tarball_release)
      local base_url resolved_file
      base_url="$(theme_context_get "kvantum_config.base_url")"
      resolved_file="$(theme_context_get "kvantum_config.resolved_file")"
      kvantum_theme="$(theme_context_get "kvantum_config.resolved_theme")"
      theme_run "create kvantum dir" mkdir -p "$HOME/.config/Kvantum"
      theme_run "remove previous kvantum theme dir" rm -rf "$HOME/.config/Kvantum/${kvantum_theme}"
      if [[ "${THEME_DRY_RUN}" == "1" ]]; then
        echo "[dry-run] curl ${base_url}/${resolved_file} | tar -xz -C ~/.config/Kvantum/"
      else
        curl -fLso /tmp/theme-kvantum.tar.gz "${base_url}/${resolved_file}"
        tar -xz -C "$HOME/.config/Kvantum/" -f /tmp/theme-kvantum.tar.gz
        rm -f /tmp/theme-kvantum.tar.gz
      fi
      ;;

    "")
      theme_warn "kvantum_config.method is empty; skipping kvantum install"
      return 0
      ;;

    *)
      theme_warn "Unknown kvantum method '${kvantum_method}'; skipping"
      return 0
      ;;
  esac

  theme_run_shell "activate kvantum theme" "printf '[General]\ntheme=${kvantum_theme}\n' > ${HOME}/.config/Kvantum/kvantum.kvconfig"
  theme_run "set KDE widget style" kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
}
```

**Key changes from original:**
- `kvantum_repo` moved inside `catppuccin_repo` and `kvantum_repo` cases (no longer fetched at top)
- `kvantum_theme` read with `|| kvantum_theme=""` fallback so it's safe when not in derived
- New `tarball_release` case overrides `kvantum_theme` from `kvantum_config.resolved_theme`

**Step 3: Smoke-test with dry-run (Catppuccin — existing method must still work)**

```bash
cd /path/to/Linux-Setup
bash scripts/theme-switch.sh \
  --theme catppuccin --flavor mocha --accent mauve \
  --dry-run --non-interactive 2>&1 | grep -A5 "Running adapter: kde"
```
Expected: see `[dry-run] run catppuccin/kde install.sh` lines, no errors.

**Step 4: Smoke-test with dry-run (Rose Pine — new method, after Task 3 manifest update)**

```bash
bash scripts/theme-switch.sh \
  --theme rosepine --flavor moon --accent iris \
  --dry-run --non-interactive 2>&1 | grep -i kvantum
```
Expected:
```
[theme:info] Kvantum disabled for this theme; skipping
```
(This is expected because the manifest still has `enabled: false` until Task 3. Run this test again after Task 3 to confirm it switches to the tarball path.)

**Step 5: Commit**

```bash
git add scripts/lib/theme-apply-kde.sh
git commit -m "feat(theme): add tarball_release Kvantum install method, move repo/theme fetches into case branches"
```

---

## Task 3: Update rosepine.json manifest

**Files:**
- Modify: `themes/manifests/rosepine.json`

**Step 1: Update kvantum_config**

Replace:
```json
"kvantum_config": {
  "enabled": false
},
```
with:
```json
"kvantum_config": {
  "enabled": true,
  "method": "tarball_release",
  "base_url": "https://raw.githubusercontent.com/rose-pine/kvantum/master/dist",
  "file_pattern": "rose-pine-${flavor}-${accent}.tar.gz",
  "files_by_flavor": {
    "main": "rose-pine-${accent}.tar.gz"
  }
},
```

**Step 2: Remove stale kvantum_theme from derived_patterns**

In `derived_patterns`, remove:
```json
"kvantum_theme": "RosePine",
```
(The `tarball_release` case reads `kvantum_config.resolved_theme` directly; it no longer uses `derived.kvantum_theme`.)

**Step 3: Re-run the context verification from Task 1, Step 3**

```bash
THEME_CONTEXT_JSON="$(bash -c '
  source scripts/lib/theme-common.sh
  theme_build_context_json rosepine moon iris
')"
echo "$THEME_CONTEXT_JSON" | python3 -c "
import json,sys
ctx=json.load(sys.stdin)
kv=ctx['kvantum_config']
print('enabled:', kv['enabled'])
print('method:', kv['method'])
print('resolved_file:', kv.get('resolved_file'))
print('resolved_theme:', kv.get('resolved_theme'))
"
```
Expected:
```
enabled: true
method: tarball_release
resolved_file: rose-pine-moon-iris.tar.gz
resolved_theme: rose-pine-moon-iris
```

**Step 4: Dry-run the full Rose Pine switch**

```bash
bash scripts/theme-switch.sh \
  --theme rosepine --flavor moon --accent iris \
  --dry-run --non-interactive 2>&1 | grep -i kvantum
```
Expected:
```
[dry-run] create kvantum dir :: mkdir -p /home/<user>/.config/Kvantum
[dry-run] remove previous kvantum theme dir :: rm -rf /home/<user>/.config/Kvantum/rose-pine-moon-iris
[dry-run] curl https://raw.githubusercontent.com/rose-pine/kvantum/master/dist/rose-pine-moon-iris.tar.gz | tar -xz -C ~/.config/Kvantum/
[dry-run] activate kvantum theme :: printf '[General]\ntheme=rose-pine-moon-iris\n' > ...
[dry-run] set KDE widget style :: kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
```

Also test main flavor:
```bash
bash scripts/theme-switch.sh \
  --theme rosepine --flavor main --accent love \
  --dry-run --non-interactive 2>&1 | grep -i kvantum
```
Expected tarball URL ends with `rose-pine-love.tar.gz` (no "main").

Also confirm Catppuccin dry-run still works after manifest edit (no regression):
```bash
bash scripts/theme-switch.sh \
  --theme catppuccin --flavor mocha --accent mauve \
  --dry-run --non-interactive 2>&1 | grep -c '\[dry-run\]'
```
Expected: non-zero count, no errors.

**Step 5: Commit**

```bash
git add themes/manifests/rosepine.json
git commit -m "feat(theme): enable Kvantum for Rose Pine via tarball_release method"
```

---

## Task 4: Update docs/themes.md

**Files:**
- Modify: `docs/themes.md`

**Step 1: Remove the Kvantum caveat for Rose Pine**

Find and remove this line from the Caveats section:
```
- Rose Pine: Kvantum is skipped; the Qt widget style will remain as-is from the previous theme.
```

**Step 2: Update the tokyonight section note**

Find:
```
- Note: Kvantum is skipped for Rose Pine (no official theme). The widget style remains whatever was last set.
```
Replace with:
```
- Note: Kvantum is installed per flavor+accent from `rose-pine/kvantum` prebuilt tarballs.
```

**Step 3: Commit**

```bash
git add docs/themes.md
git commit -m "docs(themes): update Rose Pine Kvantum note, remove stale caveat"
```
