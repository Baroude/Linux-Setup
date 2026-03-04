#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/theme-common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/theme-apply-kde.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/theme-apply-terminal.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/theme-apply-editors.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/theme-apply-cli.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/theme-apply-panel.sh"

arg_theme=""
arg_flavor=""
arg_accent=""
flag_list=0
flag_current=0
flag_non_interactive=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme)
      arg_theme="${2:-}"
      shift 2
      ;;
    --flavor)
      arg_flavor="${2:-}"
      shift 2
      ;;
    --accent)
      arg_accent="${2:-}"
      shift 2
      ;;
    --list)
      flag_list=1
      shift
      ;;
    --dry-run)
      THEME_DRY_RUN=1
      shift
      ;;
    --current)
      flag_current=1
      shift
      ;;
    --non-interactive)
      flag_non_interactive=1
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage: scripts/theme-switch.sh [options]

Options:
  --theme <name>
  --flavor <name>
  --accent <name>
  --list
  --dry-run
  --current
  --non-interactive
EOF
      exit 0
      ;;
    *)
      theme_err "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ "$flag_list" == "1" ]]; then
  theme_list_available
  exit 0
fi

if [[ "$flag_current" == "1" && -z "$arg_theme$arg_flavor$arg_accent" ]]; then
  theme_print_current_state
  exit 0
fi

defaults_json="$(theme_defaults_json)"
default_theme="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["theme"])' <<<"$defaults_json")"
default_flavor="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["flavor"])' <<<"$defaults_json")"
default_accent="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["accent"])' <<<"$defaults_json")"

saved_theme=""
saved_flavor=""
saved_accent=""
if readarray -t state_triplet < <(theme_read_state_selection 2>/dev/null); then
  saved_theme="${state_triplet[0]:-}"
  saved_flavor="${state_triplet[1]:-}"
  saved_accent="${state_triplet[2]:-}"
fi

selected_theme="${arg_theme:-${saved_theme:-$default_theme}}"
selected_flavor="${arg_flavor:-${saved_flavor:-$default_flavor}}"
selected_accent="${arg_accent:-${saved_accent:-$default_accent}}"

if ! theme_validate_selection "$selected_theme" "$selected_flavor" "$selected_accent"; then
  theme_write_state "failed" "false" "" "$selected_theme" "$selected_flavor" "$selected_accent" || true
  exit 1
fi

THEME_CONTEXT_JSON="$(theme_build_context_json "$selected_theme" "$selected_flavor" "$selected_accent")"
export THEME_CONTEXT_JSON

theme_write_context_file

theme_info "Selected theme: ${selected_theme}/${selected_flavor}/${selected_accent}"
[[ "$flag_non_interactive" == "1" ]] && theme_info "Non-interactive mode enabled"

completed=()
failed=0
restart_pending="$(theme_restart_pending_default)"

run_adapter() {
  local name="$1"
  local fn="$2"
  theme_info "Running adapter: ${name}"
  if "$fn"; then
    completed+=("$name")
    return 0
  fi
  theme_warn "Adapter failed: ${name}"
  failed=$((failed + 1))
  return 1
}

run_adapter "kde" theme_apply_kde_adapter || true
run_adapter "terminal" theme_apply_terminal_adapter || true
run_adapter "editors" theme_apply_editors_adapter || true
run_adapter "cli" theme_apply_cli_adapter || true
theme_info "Running adapter: panel"
panel_rc=0
theme_apply_panel_adapter || panel_rc=$?
if [[ $panel_rc -eq 0 ]]; then
  completed+=("panel")
elif [[ $panel_rc -eq 2 ]]; then
  restart_pending="true"
  theme_warn "Panel adapter deferred: applet not yet available; will apply on next login"
else
  theme_warn "Adapter failed: panel"
  failed=$((failed + 1))
fi

status="applied"
if [[ "${#completed[@]}" -eq 0 ]]; then
  status="failed"
elif [[ "$failed" -gt 0 ]]; then
  status="partial"
fi

completed_csv=""
if [[ "${#completed[@]}" -gt 0 ]]; then
  completed_csv="$(IFS=,; echo "${completed[*]}")"
fi

theme_write_state "$status" "$restart_pending" "$completed_csv" "$selected_theme" "$selected_flavor" "$selected_accent"

theme_info "Result: ${status}"
if [[ "$status" != "applied" ]]; then
  exit 1
fi
