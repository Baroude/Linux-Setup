#!/usr/bin/env bash
# doctor.sh — Verify the linux-setup installation without making any changes.
# Reports PASS/WARN/FAIL for each check and exits non-zero if any FAIL is found.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME_STATE_FILE="${HOME}/.config/linux-setup/theme-state.json"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
PASS=0; WARN=0; FAIL=0

_pass() { printf '\033[1;32m PASS\033[0m  %s\n' "$*"; PASS=$((PASS+1)); }
_warn() { printf '\033[1;33m WARN\033[0m  %s\n' "$*"; WARN=$((WARN+1)); }
_fail() { printf '\033[1;31m FAIL\033[0m  %s\n' "$*"; FAIL=$((FAIL+1)); }
_head() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

check_link() {
  local target="$1"
  local expected_src="$2"
  if [[ ! -e "$target" ]]; then
    _fail "${target} — missing"
    return
  fi
  if [[ -L "$target" ]]; then
    local actual_src
    actual_src="$(readlink "$target")"
    if [[ "$actual_src" == "$expected_src" ]]; then
      _pass "${target} → ${actual_src}"
    else
      _warn "${target} symlink exists but points to ${actual_src} (expected ${expected_src})"
    fi
  else
    _warn "${target} exists but is not a symlink (was it replaced by dotbot with force?)"
  fi
}

check_file() {
  local path="$1"
  local label="${2:-$1}"
  if [[ -f "$path" ]]; then
    _pass "${label}"
  else
    _fail "${label} — not found"
  fi
}

check_cmd() {
  local cmd="$1"
  local label="${2:-$cmd}"
  if command -v "$cmd" &>/dev/null; then
    local ver
    ver="$(command -v "$cmd")"
    _pass "${label} (${ver})"
  else
    _fail "${label} — command not found"
  fi
}

check_cmd_any() {
  # Pass if any of the given commands is available. Usage: check_cmd_any "label" cmd1 cmd2 ...
  local label="$1"
  shift
  for cmd in "$@"; do
    if command -v "$cmd" &>/dev/null; then
      _pass "${label} (${cmd})"
      return
    fi
  done
  _fail "${label} — none of: $*"
}

check_kconfig() {
  local file="$1"
  local group="$2"
  local key="$3"
  local expected="$4"
  if ! command -v kreadconfig6 &>/dev/null; then
    _warn "kreadconfig6 not found; skipping KDE config checks"
    return
  fi
  local actual
  actual="$(kreadconfig6 --file "$file" --group "$group" --key "$key" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    _pass "kconfig ${file} [${group}] ${key}=${actual}"
  else
    _fail "kconfig ${file} [${group}] ${key} — expected '${expected}', got '${actual}'"
  fi
}

# ---------------------------------------------------------------------------
# 1. Theme state
# ---------------------------------------------------------------------------
_head "Theme state"

if [[ ! -f "$THEME_STATE_FILE" ]]; then
  _warn "No theme state file at ${THEME_STATE_FILE} — theme-switch.sh has not been run"
else
  THEME_NAME="$(python3 -c "import json; s=json.load(open('${THEME_STATE_FILE}')); print(s.get('theme','?'))" 2>/dev/null || echo "?")"
  THEME_FLAVOR="$(python3 -c "import json; s=json.load(open('${THEME_STATE_FILE}')); print(s.get('flavor','?'))" 2>/dev/null || echo "?")"
  THEME_ACCENT="$(python3 -c "import json; s=json.load(open('${THEME_STATE_FILE}')); print(s.get('accent','?'))" 2>/dev/null || echo "?")"
  THEME_STATUS="$(python3 -c "import json; s=json.load(open('${THEME_STATE_FILE}')); print(s.get('status','?'))" 2>/dev/null || echo "?")"
  THEME_RESTART="$(python3 -c "import json; s=json.load(open('${THEME_STATE_FILE}')); print(s.get('restart_pending',False))" 2>/dev/null || echo "?")"

  if [[ "$THEME_STATUS" == "applied" ]]; then
    _pass "Theme: ${THEME_NAME}/${THEME_FLAVOR}/${THEME_ACCENT} (${THEME_STATUS})"
  elif [[ "$THEME_STATUS" == "partial" ]]; then
    _warn "Theme: ${THEME_NAME}/${THEME_FLAVOR}/${THEME_ACCENT} — status is 'partial' (some adapters failed)"
  else
    _fail "Theme: ${THEME_NAME}/${THEME_FLAVOR}/${THEME_ACCENT} — status is '${THEME_STATUS}'"
  fi

  if [[ "$THEME_RESTART" == "True" ]]; then
    _warn "Session restart pending — run: kquitapp6 plasmashell && kstart6 plasmashell"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Dotbot symlinks
# ---------------------------------------------------------------------------
_head "Dotbot symlinks"

check_link "$HOME/.zshrc"                                          "${REPO_DIR}/zshrc"
check_link "$HOME/.zshenv"                                         "${REPO_DIR}/zsh/zshenv"
check_link "$HOME/.gitconfig"                                      "${REPO_DIR}/gitconfig"
check_link "$HOME/.config/kitty/kitty.conf"                        "${REPO_DIR}/kitty/kitty.conf"
check_link "$HOME/.config/nvim"                                    "${REPO_DIR}/nvim"
check_link "$HOME/.config/fastfetch/config.jsonc"                  "${REPO_DIR}/fastfetch/config.jsonc"
check_link "$HOME/.config/plasma-workspace/env/envvars.sh"         "${REPO_DIR}/environment/envvars.sh"
check_link "$HOME/.config/gtk-4.0/gtk.css"                        "${REPO_DIR}/gtk/gtk-4.0-gtk.css"

# ---------------------------------------------------------------------------
# 3. Plasma-specific symlinks (install-plasma.conf.yaml — optional)
# ---------------------------------------------------------------------------
_head "Plasma symlinks (install-plasma.conf.yaml)"

for f in kwinrc kscreenlockerrc kwinrulesrc; do
  target="$HOME/.config/${f}"
  src="${REPO_DIR}/plasma/${f}"
  if [[ -e "$target" ]]; then
    check_link "$target" "$src"
  else
    _warn "${target} not linked — run: ./install -c install-plasma.conf.yaml"
  fi
done

# ---------------------------------------------------------------------------
# 4. Theme-managed outputs
# ---------------------------------------------------------------------------
_head "Theme-managed outputs"

check_file "$HOME/.config/starship.toml"                  "starship.toml"
check_file "$HOME/.config/kitty/theme.conf"               "kitty/theme.conf"
check_file "$HOME/.config/gtk-3.0/settings.ini"           "gtk-3.0/settings.ini"
check_file "$HOME/.config/fzf/colors.zsh"                 "fzf/colors.zsh"
check_file "$HOME/.config/nvim/lua/colorscheme-flavor.lua" "nvim colorscheme-flavor.lua"
check_file "$HOME/.config/bat/config"                     "bat/config"
check_file "$HOME/.config/btop/btop.conf"                 "btop/btop.conf"

# ---------------------------------------------------------------------------
# 5. Required commands
# ---------------------------------------------------------------------------
_head "Required commands"

check_cmd  zsh
check_cmd  kitty
check_cmd  nvim
check_cmd_any "rofi" rofi-wayland rofi
check_cmd  fzf
check_cmd  zoxide
check_cmd  eza
check_cmd_any "bat" batcat bat
check_cmd  btop
check_cmd  duf
check_cmd  dust
check_cmd_any "fd" fdfind fd
check_cmd  rg          "ripgrep (rg)"
check_cmd  delta       "delta (git pager)"
check_cmd  fastfetch
check_cmd  kvantummanager
check_cmd  starship
check_cmd  plasma-apply-colorscheme
check_cmd  kwriteconfig6

# ---------------------------------------------------------------------------
# 6. KDE config values
# ---------------------------------------------------------------------------
_head "KDE config values"

check_kconfig kdeglobals KDE widgetStyle kvantum
check_kconfig kdeglobals Icons Theme Papirus-Dark
check_kconfig kwinrc     Plugins kwin4_effect_better_blurEnabled true
check_kconfig kwinrc     "org.kde.kdecoration2" library org.kde.klassy

# ---------------------------------------------------------------------------
# 7. Repo git cleanliness
# ---------------------------------------------------------------------------
_head "Repo git state"

if git -C "$REPO_DIR" diff --quiet HEAD 2>/dev/null; then
  _pass "Working tree is clean"
else
  _warn "Repo has uncommitted changes (run: git -C ${REPO_DIR} diff --stat)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n'
printf '  \033[1;32mPASS\033[0m %d   \033[1;33mWARN\033[0m %d   \033[1;31mFAIL\033[0m %d\n' \
  "$PASS" "$WARN" "$FAIL"
printf '\n'

if [[ "$FAIL" -gt 0 ]]; then
  printf '\033[1;31mSetup has failures — review FAIL lines above.\033[0m\n'
  exit 1
elif [[ "$WARN" -gt 0 ]]; then
  printf '\033[1;33mSetup has warnings — review WARN lines above.\033[0m\n'
  exit 0
else
  printf '\033[1;32mAll checks passed.\033[0m\n'
  exit 0
fi
