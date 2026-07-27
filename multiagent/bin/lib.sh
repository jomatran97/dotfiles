#!/usr/bin/env bash
set -euo pipefail

ma_resolve_path() {
  # macOS-compatible realpath for scripts that may be invoked through symlinks.
  local target=$1 dir link
  while [ -L "$target" ]; do
    dir=$(cd -P "$(dirname "$target")" >/dev/null 2>&1 && pwd)
    link=$(readlink "$target")
    case "$link" in
      /*) target=$link ;;
      *) target="$dir/$link" ;;
    esac
  done
  dir=$(cd -P "$(dirname "$target")" >/dev/null 2>&1 && pwd)
  printf '%s/%s\n' "$dir" "$(basename "$target")"
}

if [ -z "${MA_LIB_LOADED:-}" ]; then
  MA_LIB_PATH=$(ma_resolve_path "${BASH_SOURCE[0]}")
  MA_BIN_DIR=$(cd -P "$(dirname "$MA_LIB_PATH")" >/dev/null 2>&1 && pwd)
  export DOTFILES=${DOTFILES:-$(cd "$MA_BIN_DIR/../.." >/dev/null 2>&1 && pwd)}
  if [ -f "$DOTFILES/multiagent/config/agents.env" ]; then
    # shellcheck disable=SC1091
    . "$DOTFILES/multiagent/config/agents.env"
  fi
  export DOTFILES MULTIAGENT_RUNS HCOM_DIR CLAUDE_CONFIG_DIR CODEX_HOME GEMINI_CONFIG_DIR MA_BIN
  export APPROVAL_MODE MAX_ITERATIONS MAX_DISPATCHES WALLCLOCK_BUDGET
  export RESEARCH_TIMEOUT PLANNER_TIMEOUT SCOUT_TIMEOUT IMPLEMENTER_TIMEOUT REVIEWER_TIMEOUT ARCHITECT_TIMEOUT HCOM_EVENT_SLICE BACKOFF_BASE BACKOFF_MAX
  MA_LIB_LOADED=1
fi

ma_ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
ma_die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ma_info() { printf '%s\n' "$*"; }
ma_have() { command -v "$1" >/dev/null 2>&1; }
ma_json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])' 2>/dev/null || sed 's/\\/\\\\/g; s/"/\\"/g'; }
# Redact to end-of-token, not just before a space: a secret at end-of-line must still match.
ma_redact() { sed -E 's/(token|secret|password|api[_-]?key|authorization)([=:[:space:]]+)(Bearer[[:space:]]+)?[^[:space:]]+/\1\2[REDACTED]/Ig'; }

ma_current_run_id() {
  [ -f "$MULTIAGENT_RUNS/CURRENT" ] || return 1
  sed -n '1p' "$MULTIAGENT_RUNS/CURRENT"
}

ma_current_run_dir() {
  local id
  id=$(ma_current_run_id) || return 1
  printf '%s/run-%s\n' "$MULTIAGENT_RUNS" "$id"
}

ma_project_dir() {
  local run_dir=${1:?run dir required}
  [ -f "$run_dir/project_dir" ] || ma_die "missing $run_dir/project_dir"
  sed -n '1p' "$run_dir/project_dir"
}

ma_log_event() {
  local run_dir=${1:?run dir}; shift
  local event=${1:?event}; shift
  mkdir -p "$run_dir"
  local msg
  msg=$(printf '%s' "$*" | ma_redact | ma_json_escape)
  printf '{"ts":"%s","event":"%s","message":"%s"}\n' "$(ma_ts)" "$event" "$msg" >> "$run_dir/run.jsonl"
}

ma_lock_do() {
  local lock=${1:?lock}; shift
  local n=0
  until mkdir "$lock" 2>/dev/null; do
    n=$((n+1)); [ "$n" -lt 50 ] || ma_die "lock timeout: $lock"
    sleep 0.1
  done
  trap 'rmdir "$lock" 2>/dev/null || true' RETURN
  "$@"
}

ma_strip_frontmatter() {
  awk 'NR==1 && $0=="---" {fm=1; next} fm && $0=="---" {fm=0; next} !fm {print}' "$1"
}

ma_yaml_field() {
  local file=${1:?file} key=${2:?key}
  awk -v k="$key" '
    NR==1 && $0=="---" {fm=1; next}
    fm && $0=="---" {exit}
    fm && $0 ~ "^" k ":" {sub("^" k ":[[:space:]]*", ""); gsub(/^"|"$/, ""); print; exit}
  ' "$file"
}

ma_sed_escape() { printf '%s' "$1" | sed 's/[\\&/]/\\&/g'; }

ma_render_text() {
  local text=${1:?text} run_dir=${2:?run_dir} task_id=${3:?task_id}
  local erun etask
  erun=$(ma_sed_escape "$run_dir"); etask=$(ma_sed_escape "$task_id")
  printf '%s' "$text" | sed "s/<RUN_DIR>/$erun/g; s/<TASK_ID>/$etask/g"
}

ma_role_file() {
  case "${1:?role}" in
    architect) printf '%s/claude/agents/architect.md\n' "$DOTFILES" ;;
    reviewer) printf '%s/claude/agents/reviewer.md\n' "$DOTFILES" ;;
    scout) printf '%s/codex/agents/scout.md\n' "$DOTFILES" ;;
    implementer) printf '%s/codex/agents/implementer.md\n' "$DOTFILES" ;;
    researcher) printf '%s/gemini/agents/researcher.md\n' "$DOTFILES" ;;
    planner) printf '%s/gemini/agents/planner.md\n' "$DOTFILES" ;;
    *) ma_die "unknown role: $1" ;;
  esac
}

ma_artifact_for() {
  local role=${1:?role} task=${2:-global}
  case "$role" in
    researcher) printf 'research.md\n' ;;
    planner) printf 'plan-proposal.md\n' ;;   # proposal only; PLAN_SCRUM.md stays architect-owned
    scout) printf 'context/%s.md\n' "$task" ;;
    implementer) printf 'implementation-%s.md\n' "$task" ;;
    reviewer) printf 'review-%s.md\n' "$task" ;;
    architect) printf 'state.md\n' ;;
    *) ma_die "unknown role: $role" ;;
  esac
}

ma_timeout_for() {
  case "${1:?role}" in
    researcher) printf '%s\n' "$RESEARCH_TIMEOUT" ;;
    planner) printf '%s\n' "$PLANNER_TIMEOUT" ;;
    scout) printf '%s\n' "$SCOUT_TIMEOUT" ;;
    implementer) printf '%s\n' "$IMPLEMENTER_TIMEOUT" ;;
    reviewer) printf '%s\n' "$REVIEWER_TIMEOUT" ;;
    architect) printf '%s\n' "$ARCHITECT_TIMEOUT" ;;
    *) printf '1200\n' ;;
  esac
}

ma_budget_check() {
  local run_dir=${1:?run_dir} role=${2:?role}
  mkdir -p "$run_dir"
  local meta="$run_dir/.budget" lock="$run_dir/.budget.lock"
  local budget_verdict=""
  _ma_budget_update() {
    local now start count
    now=$(date +%s)
    if [ -f "$meta" ]; then
      # Parse — never source — the state file: run_dir is agent-writable, and sourcing
      # would execute arbitrary shell from it.
      start=$(sed -n 's/^start_epoch=//p' "$meta" | head -n1)
      count=$(sed -n 's/^dispatch_count=//p' "$meta" | head -n1)
    fi
    start=${start:-$now}
    count=${count:-0}
    case "${start}${count}" in *[!0-9]*) start=$now; count=0 ;; esac
    count=$((count+1))
    if [ "$count" -gt "$MAX_DISPATCHES" ]; then
      ma_log_event "$run_dir" budget_abort "role=$role count=$count max=$MAX_DISPATCHES"
      budget_verdict="dispatch budget exceeded ($count > $MAX_DISPATCHES)"
      return 0   # die OUTSIDE the lock, or the RETURN trap never releases it (ma_die exits)
    fi
    if [ $((now-start)) -gt "$WALLCLOCK_BUDGET" ]; then
      ma_log_event "$run_dir" budget_abort "role=$role elapsed=$((now-start)) max=$WALLCLOCK_BUDGET"
      budget_verdict="wallclock budget exceeded"
      return 0
    fi
    # atomic write: temp + rename, so a crash mid-write can't leave a half-written state file
    printf 'start_epoch=%s\ndispatch_count=%s\n' "$start" "$count" > "$meta.tmp" && mv -f "$meta.tmp" "$meta"
  }
  ma_lock_do "$lock" _ma_budget_update
  [ -z "$budget_verdict" ] || ma_die "$budget_verdict"
}

ma_hcom_config_set() {
  local key=${1:?key} value=${2:?value}
  if ! ma_have hcom; then
    printf 'SKIP hcom config %s=%s (hcom not found)\n' "$key" "$value"
    return 1
  fi
  if hcom config "$key" "$value" >/dev/null 2>&1; then
    printf 'SET hcom config %s=%s\n' "$key" "$value"; return 0
  fi
  if hcom config set "$key" "$value" >/dev/null 2>&1; then
    printf 'SET hcom config %s=%s\n' "$key" "$value"; return 0
  fi
  if hcom config "$key=$value" >/dev/null 2>&1; then
    printf 'SET hcom config %s=%s\n' "$key" "$value"; return 0
  fi
  printf 'WARN failed to set hcom config %s=%s\n' "$key" "$value" >&2
  return 1
}
