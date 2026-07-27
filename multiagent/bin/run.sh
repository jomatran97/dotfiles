#!/usr/bin/env bash
set -euo pipefail
SCRIPT_PATH=${BASH_SOURCE[0]}
while [ -L "$SCRIPT_PATH" ]; do
  DIR=$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)
  LINK=$(readlink "$SCRIPT_PATH")
  case "$LINK" in /*) SCRIPT_PATH=$LINK ;; *) SCRIPT_PATH="$DIR/$LINK" ;; esac
done
SCRIPT_DIR=$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)
# shellcheck source=multiagent/bin/lib.sh
. "$SCRIPT_DIR/lib.sh"

goal=${*:-}
[ -n "$goal" ] || ma_die 'usage: ma-run "<goal>"'
export APPROVAL_MODE=auto
cleanup() {
  local t
  if ma_have hcom; then
    for t in researcher planner scout implementer reviewer architect; do hcom kill "tag:$t" >/dev/null 2>&1 || true; done
  fi
}
trap cleanup EXIT INT TERM
"$DOTFILES/multiagent/bin/new-run.sh" "$goal"
run_dir=$(ma_current_run_dir) || ma_die "no current run"
role_file=$(ma_role_file architect)
role_text=$(ma_render_text "$(ma_strip_frontmatter "$role_file")" "$run_dir" global)
prompt=$(cat <<EOF
Unattended run. APPROVAL_MODE=auto.
RUN_DIR=$run_dir
Goal: $goal

Execute the full Magentic + Sequential + Maker-checker loop. Use ma-dispatch for workers, ma-status for polling, update PLAN_SCRUM.md/state.md, and create $run_dir/final.md.done when complete.
EOF
)
if ! ma_have hcom; then ma_die "hcom not found; cannot run unattended"; fi
hcom kill tag:architect >/dev/null 2>&1 || true
# architect.settings.json grants Read only under /Users/ryanparker/Documents/personal/code/**;
# a project outside that tree is unreadable to the headless architect (prompts auto-deny).
proj_check=$(sed -n '1p' "$run_dir/project_dir" 2>/dev/null || true)
case "$proj_check" in
  /Users/ryanparker/Documents/personal/code/*) : ;;
  *) printf 'WARN project %s is outside the Read scope in claude/architect.settings.json — headless reads of it will be denied\n' "$proj_check" >&2 ;;
esac
ma_log_event "$run_dir" unattended_launch "goal=$goal"
hcom claude --headless --tag architect --permission-mode acceptEdits --add-dir "$run_dir" --settings "$DOTFILES/claude/architect.settings.json" --hcom-system-prompt "$role_text" --hcom-prompt "$prompt"
# Bounded by ARCHITECT_TIMEOUT (wallclock). MAX_ITERATIONS is the maker-checker retry
# bound owned by the architect and must NOT double as this driver's poll counter.
start=$(date +%s); iter=0
while :; do
  iter=$((iter+1))
  [ -f "$run_dir/final.md.done" ] && { ma_log_event "$run_dir" unattended_done "iterations=$iter"; printf 'DONE run_dir=%s\n' "$run_dir"; exit 0; }
  now=$(date +%s)
  if [ $((now-start)) -gt "$ARCHITECT_TIMEOUT" ]; then ma_log_event "$run_dir" unattended_timeout "elapsed=$((now-start)) iterations=$iter"; ma_die "unattended run timed out after ${ARCHITECT_TIMEOUT}s"; fi
  if hcom events --wait "to:architect,tag:architect,stopped,collision" --timeout "$HCOM_EVENT_SLICE" >> "$run_dir/run.events.log" 2>&1; then
    ma_log_event "$run_dir" events_wait "slice=$HCOM_EVENT_SLICE iter=$iter"
  else
    sleep 5
  fi
  if [ ! -f "$run_dir/final.md.done" ]; then hcom send -b @architect -- "CONTINUE run=$run_dir iter=$iter check PLAN_SCRUM/state and proceed or finalize" >/dev/null 2>&1 || true; fi
done
