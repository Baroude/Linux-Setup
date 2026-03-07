#!/usr/bin/env bash

# Shared helpers for linux-setup theming.

THEME_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_REPO_DIR="$(cd "${THEME_LIB_DIR}/../.." && pwd)"
THEME_CATALOG_FILE="${THEME_REPO_DIR}/themes/catalog.json"
THEME_STATE_FILE="${HOME}/.config/linux-setup/theme-state.json"
THEME_CONTEXT_FILE="${HOME}/.config/linux-setup/theme-context.json"
THEME_DRY_RUN="${THEME_DRY_RUN:-0}"

_theme_log() {
  local level="$1"
  shift
  printf '[theme:%s] %s\n' "$level" "$*"
}

theme_info() { _theme_log info "$@"; }
theme_warn() { _theme_log warn "$@"; }
theme_err() { _theme_log err "$@" >&2; }

theme_ensure_state_dir() {
  mkdir -p "$(dirname "$THEME_STATE_FILE")"
}

theme_run() {
  local message="$1"
  shift
  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    printf '[dry-run] %s ::' "$message"
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

theme_run_shell() {
  local message="$1"
  local script="$2"
  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    printf '[dry-run] %s :: %s\n' "$message" "$script"
    return 0
  fi
  bash -c "$script"
}

theme_clone_fresh() {
  local target="$1"
  local url="$2"
  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    printf '[dry-run] clone %s -> %s\n' "$url" "$target"
    return 0
  fi
  rm -rf "$target"
  git clone --depth=1 "$url" "$target"
}

theme_defaults_json() {
  python3 - "$THEME_CATALOG_FILE" <<'PY'
import json, sys
catalog = json.load(open(sys.argv[1], encoding='utf-8'))
print(json.dumps(catalog["defaults"], separators=(",", ":")))
PY
}

theme_list_available() {
  python3 - "$THEME_CATALOG_FILE" <<'PY'
import json, sys
catalog = json.load(open(sys.argv[1], encoding='utf-8'))
for name, data in catalog["themes"].items():
    if not data.get("supported", True):
        desc = data.get("description", "not yet implemented")
        print(f"theme: {name}  [{desc}]")
        continue
    flavors = ', '.join(data["flavors"])
    accents = ', '.join(data["accents"])
    print(f"theme: {name}")
    print(f"  flavors: {flavors}")
    print(f"  accents: {accents}")
PY
}

theme_read_state_selection() {
  if [[ ! -f "$THEME_STATE_FILE" ]]; then
    return 1
  fi
  python3 - "$THEME_STATE_FILE" <<'PY'
import json, sys
state = json.load(open(sys.argv[1], encoding='utf-8'))
for key in ("theme", "flavor", "accent"):
    print(state.get(key, ""))
PY
}

theme_print_current_state() {
  if [[ ! -f "$THEME_STATE_FILE" ]]; then
    echo "No theme state file found at $THEME_STATE_FILE"
    return 0
  fi
  python3 - "$THEME_STATE_FILE" <<'PY'
import json, sys

ALL_ADAPTERS = ["kde", "terminal", "editors", "cli", "apps", "panel"]

state = json.load(open(sys.argv[1], encoding='utf-8'))
theme   = state.get("theme", "?")
flavor  = state.get("flavor", "?")
accent  = state.get("accent", "?")
status  = state.get("status", "?")
applied = state.get("last_applied", "?")
completed = state.get("completed_adapters", [])
restart   = state.get("restart_pending", False)

print(f"Theme:    {theme}/{flavor}/{accent}")
print(f"Status:   {status}")
print(f"Applied:  {applied}")
print()
print("Adapters:")
for adapter in ALL_ADAPTERS:
    mark = "[ok]" if adapter in completed else "[ ]"
    print(f"  {mark} {adapter}")

if restart:
    print()
    print("[!] Session restart pending.")
    print("    Run: kquitapp6 plasmashell && kstart6 plasmashell")

missing = [a for a in ALL_ADAPTERS if a not in completed]
if status == "partial" and missing:
    print()
    print(f"[!] Partial apply — missing: {', '.join(missing)}")
    print("    Re-run: scripts/theme-switch.sh to retry failed adapters.")
elif status == "failed":
    print()
    print("[!] Apply failed before any adapter ran.")
    print("    Re-run: scripts/theme-switch.sh to retry.")
PY
}

theme_build_context_json() {
  local theme="$1"
  local flavor="$2"
  local accent="$3"
  python3 - "$THEME_CATALOG_FILE" "$THEME_REPO_DIR" "$theme" "$flavor" "$accent" <<'PY'
import json
import sys
from pathlib import Path
from string import Template

catalog_path, repo_dir, theme, flavor, accent = sys.argv[1:]
catalog = json.load(open(catalog_path, encoding='utf-8'))
if theme not in catalog["themes"]:
    raise SystemExit(f"unsupported theme: {theme}")
entry = catalog["themes"][theme]
if flavor not in entry["flavors"]:
    raise SystemExit(f"unsupported flavor '{flavor}' for theme '{theme}'")
if accent not in entry["accents"]:
    raise SystemExit(f"unsupported accent '{accent}' for theme '{theme}'")

manifest_path = Path(repo_dir) / entry["manifest"]
manifest = json.load(open(manifest_path, encoding='utf-8'))
palette = manifest["flavors"][flavor]
accent_slot = manifest["accents"][accent]
accent_hex = palette[accent_slot]

params = {
    "flavor": flavor,
    "accent": accent,
    "FlavorTitle": flavor.title(),
    "AccentTitle": accent.title(),
}
derived = {}
for key, pattern in manifest["derived_patterns"].items():
    derived[key] = Template(pattern).safe_substitute(params)

widget_colors = {}
for widget, slot in manifest.get("widget_slot_map", {}).items():
    if slot == "accent":
        widget_colors[widget] = accent_hex
    else:
        widget_colors[widget] = palette.get(slot, accent_hex)

tokens = {k.upper(): v for k, v in palette.items()}
tokens["ACCENT"] = accent_hex
tokens["FLAVOR"] = flavor
tokens["ACCENT_NAME"] = accent
tokens["THEME"] = theme

if "gtk_theme" in derived:
    tokens["GTK_THEME"] = derived["gtk_theme"]
if "gtk_cursor_theme" in derived:
    tokens["GTK_CURSOR_THEME"] = derived["gtk_cursor_theme"]
if "starship_palette" in derived:
    tokens["STARSHIP_PALETTE_NAME"] = derived["starship_palette"]

# Resolve install configs with template substitution
def resolve_config(cfg):
    if not cfg:
        return cfg
    return {k: Template(v).safe_substitute(params) if isinstance(v, str) else v
            for k, v in cfg.items()}

context = {
    "theme": theme,
    "flavor": flavor,
    "accent": accent,
    "accent_slot": accent_slot,
    "accent_hex": accent_hex,
    "tokens": tokens,
    "derived": derived,
    "kde_installer_index": manifest.get("kde_installer_index", {}),
    "kde_install_config": resolve_config(manifest.get("kde_install_config", {})),
    "kvantum_config": resolve_config(manifest.get("kvantum_config", {"enabled": False})),
    "gtk_install_config": resolve_config(manifest.get("gtk_install_config", {})),
    "bat_theme_config": resolve_config(manifest.get("bat_theme_config", {})),
    "btop_theme_config": resolve_config(manifest.get("btop_theme_config", {})),
    "firefox_config": resolve_config(manifest.get("firefox_config", {"method": "none"})),
    "widget_colors": widget_colors,
    "components": entry.get("components", {}),
}
print(json.dumps(context, separators=(",", ":")))
PY
}

theme_context_get() {
  local path="$1"
  python3 - "$path" <<'PY'
import json
import os
import sys

path = sys.argv[1].split('.')
ctx = json.loads(os.environ['THEME_CONTEXT_JSON'])
cur = ctx
for part in path:
    cur = cur[part]
if isinstance(cur, (dict, list)):
    print(json.dumps(cur, separators=(',', ':')))
else:
    print(cur)
PY
}

theme_render_template() {
  local template_path="$1"
  local out_path="$2"
  mkdir -p "$(dirname "$out_path")"
  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] render ${template_path} -> ${out_path}"
    return 0
  fi
  THEME_TEMPLATE_PATH="$template_path" THEME_OUTPUT_PATH="$out_path" python3 <<'PY'
import json
import os
from pathlib import Path
from string import Template

ctx = json.loads(os.environ['THEME_CONTEXT_JSON'])
mapping = {}
mapping.update(ctx['tokens'])
mapping.update({k.upper(): v for k, v in ctx['derived'].items()})

src = Path(os.environ['THEME_TEMPLATE_PATH'])
out = Path(os.environ['THEME_OUTPUT_PATH'])
text = src.read_text(encoding='utf-8')
rendered = Template(text).safe_substitute(mapping)

tmp = out.with_suffix(out.suffix + '.tmp')
tmp.write_text(rendered, encoding='utf-8')
tmp.replace(out)
PY
}

theme_validate_selection() {
  local theme="$1"
  local flavor="$2"
  local accent="$3"
  python3 - "$THEME_CATALOG_FILE" "$theme" "$flavor" "$accent" <<'PY'
import json, sys
catalog_path, theme, flavor, accent = sys.argv[1:]
catalog = json.load(open(catalog_path, encoding='utf-8'))
if theme not in catalog['themes']:
    print(f"Unknown theme '{theme}'.", file=sys.stderr)
    supported = [k for k, v in catalog['themes'].items() if v.get('supported', True)]
    print("Available themes:", ', '.join(sorted(supported)), file=sys.stderr)
    raise SystemExit(1)
entry = catalog['themes'][theme]
if not entry.get('supported', True):
    desc = entry.get('description', 'not yet implemented')
    print(f"Theme '{theme}' is not yet implemented: {desc}", file=sys.stderr)
    supported = [k for k, v in catalog['themes'].items() if v.get('supported', True)]
    print("Available themes:", ', '.join(sorted(supported)), file=sys.stderr)
    raise SystemExit(1)
if flavor not in entry['flavors']:
    print(f"Unsupported flavor '{flavor}' for theme '{theme}'.", file=sys.stderr)
    print("Valid flavors:", ', '.join(entry['flavors']), file=sys.stderr)
    raise SystemExit(1)
if accent not in entry['accents']:
    print(f"Unsupported accent '{accent}' for theme '{theme}'.", file=sys.stderr)
    print("Valid accents:", ', '.join(entry['accents']), file=sys.stderr)
    raise SystemExit(1)
PY
}

theme_write_state() {
  local status="$1"
  local restart_pending="$2"
  local completed_adapters_csv="$3"
  local theme="$4"
  local flavor="$5"
  local accent="$6"

  theme_ensure_state_dir

  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] write state status=${status} restart_pending=${restart_pending} completed=${completed_adapters_csv}"
    return 0
  fi

  THEME_STATUS="$status" \
  THEME_RESTART_PENDING="$restart_pending" \
  THEME_COMPLETED_ADAPTERS="$completed_adapters_csv" \
  THEME_NAME="$theme" \
  THEME_FLAVOR="$flavor" \
  THEME_ACCENT="$accent" \
  THEME_STATE_FILE="$THEME_STATE_FILE" \
  python3 <<'PY'
import json
import os
from datetime import datetime, timezone

state_path = os.environ['THEME_STATE_FILE']
completed = [x for x in os.environ.get('THEME_COMPLETED_ADAPTERS', '').split(',') if x]

state = {
    'theme': os.environ['THEME_NAME'],
    'flavor': os.environ['THEME_FLAVOR'],
    'accent': os.environ['THEME_ACCENT'],
    'status': os.environ['THEME_STATUS'],
    'completed_adapters': completed,
    'restart_pending': os.environ.get('THEME_RESTART_PENDING', 'false').lower() == 'true',
    'last_applied': datetime.now(timezone.utc).isoformat(),
}

with open(state_path, 'w', encoding='utf-8') as fh:
    json.dump(state, fh, indent=2)
PY
}

theme_write_context_file() {
  theme_ensure_state_dir
  if [[ "${THEME_DRY_RUN}" == "1" ]]; then
    echo "[dry-run] write context ${THEME_CONTEXT_FILE}"
    return 0
  fi
  printf '%s\n' "$THEME_CONTEXT_JSON" > "$THEME_CONTEXT_FILE"
}

theme_restart_pending_default() {
  if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
    echo "false"
  else
    echo "true"
  fi
}
