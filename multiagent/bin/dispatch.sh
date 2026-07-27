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

watchdog() {
  local role=$1 task_id=$2 run_dir=$3 timeout_s=$4 done_flag=$5 pid_file=${6:-}
  # Self-cleanup: remove our pid file on ANY exit, but only if it still records THIS
  # process (a newer dispatch may already have replaced it). Prevents PID-reuse kills.
  # shellcheck disable=SC2064
  trap '{ [ -n "$pid_file" ] && [ "$(cat "$pid_file" 2>/dev/null || true)" = "$$" ] && rm -f "$pid_file"; } || true' EXIT
  sleep "$timeout_s"
  if [ -f "$done_flag" ]; then exit 0; fi
  ma_log_event "$run_dir" timeout "role=$role task=$task_id timeout=$timeout_s"
  if ma_have hcom; then
    hcom kill "tag:$role" >/dev/null 2>&1 || true
    hcom send -b @architect -- "TIMEOUT role=$role task=$task_id run=$run_dir timeout=$timeout_s" >/dev/null 2>&1 || true
  fi
}

if [ "${1:-}" = "--watchdog" ]; then
  shift; watchdog "$@"; exit 0
fi

role=${1:-}; task_id=${2:-global}
[ -n "$role" ] || ma_die "usage: ma-dispatch <role> [task-id]"
# task_id becomes part of artifact PATHS — reject traversal/metacharacters outright.
case "$task_id" in
  *[!A-Za-z0-9._-]*|.|..) ma_die "invalid task-id '$task_id' (allowed: letters digits . _ -)" ;;
esac
run_dir=$(ma_current_run_dir) || ma_die "no current run; run ma-new-run first"
project_dir=$(ma_project_dir "$run_dir")
role_file=$(ma_role_file "$role")
artifact_rel=$(ma_artifact_for "$role" "$task_id")
artifact="$run_dir/$artifact_rel"
done_flag="$artifact.done"
timeout_s=$(ma_timeout_for "$role")
mkdir -p "$(dirname "$artifact")"
ma_budget_check "$run_dir" "$role"
raw_body=$(ma_strip_frontmatter "$role_file")
role_text=$(ma_render_text "$raw_body" "$run_dir" "$task_id")
model=$(ma_yaml_field "$role_file" model || true); model=${model:-default}
user_prompt=$(cat <<EOF
You are role=$role for task=$task_id.
RUN_DIR=$run_dir
PROJECT_DIR=$project_dir
ARTIFACT=$artifact
DONE_FLAG=$done_flag

Follow your system prompt exactly. Write the artifact first, create the .done flag last, then send the DONE token to @architect.
EOF
)
user_prompt=$(ma_render_text "$user_prompt" "$run_dir" "$task_id")
ma_log_event "$run_dir" dispatch "role=$role task=$task_id artifact=$artifact timeout=$timeout_s model=$model"
if ma_have hcom; then hcom kill "tag:$role" >/dev/null 2>&1 || true; else ma_die "hcom not found; cannot dispatch $role"; fi
# Clear any stale .done from a previous attempt, or the watchdog exits immediately
# and ma-status reports a false completion for this dispatch.
rm -f "$done_flag"
cmd=(hcom)
case "$role" in
  # Reviewer needs BOTH trees: project (cwd via --dir) and the run dir (--add-dir, forwarded to claude).
  # acceptEdits only auto-approves within the working dir + additionalDirectories.
  reviewer) cmd+=(claude --headless --dir "$project_dir" --tag "$role" --permission-mode acceptEdits --add-dir "$run_dir" --settings "$DOTFILES/claude/reviewer.settings.json") ;;
  scout|implementer) cmd+=(codex --headless --dir "$project_dir" --tag "$role") ;;
  # researcher/planner (agy): cwd = RUN_DIR so their artifact writes are IN-workspace.
  # agy has no writable_roots equivalent and its out-of-cwd write sandbox is unverified;
  # codex needed writable_roots for exactly this. They READ the project via the absolute
  # path stored in <RUN_DIR>/project_dir (reads are typically unrestricted).
  researcher|planner) cmd+=(agy --terminal tmux --dir "$run_dir" --tag "$role") ;;
  *) ma_die "unknown dispatch role: $role" ;;
esac
if [ "$model" != "default" ] && [ -n "$model" ]; then cmd+=(--model "$model"); fi
cmd+=(--hcom-system-prompt "$role_text" --hcom-prompt "$user_prompt")
# Reap any stale watchdog for this role first: without this, a watchdog from a previous
# attempt can later kill the NEW instance of the same tag and inject a spurious TIMEOUT.
wd_pid_file="$run_dir/.wd-$role.pid"
if [ -f "$wd_pid_file" ]; then
  old_wd=$(cat "$wd_pid_file" 2>/dev/null || true)
  # PIDs get recycled: only signal if the process is verifiably OUR watchdog for this role.
  # -ww is REQUIRED: without it macOS/BSD ps truncates to ~79 cols when no tty is attached,
  # and the "--watchdog <role>" literal sits past offset 80 (long script path) — the grep
  # would never match and stale watchdogs would never be reaped.
  if [ -n "$old_wd" ] && ps -ww -o command= -p "$old_wd" 2>/dev/null | grep -Fq -- "--watchdog $role "; then
    kill "$old_wd" >/dev/null 2>&1 || true
  fi
  rm -f "$wd_pid_file"
fi
# Start the watchdog BEFORE launching so there is no unguarded window.
# NOTE: pid-file handling assumes dispatches are sequential (single architect); it is not
# locked. The budget lock serialises the common path.
nohup "$SCRIPT_PATH" --watchdog "$role" "$task_id" "$run_dir" "$timeout_s" "$done_flag" "$wd_pid_file" >/dev/null 2>&1 &
watchdog_pid=$!
printf '%s\n' "$watchdog_pid" > "$wd_pid_file"
# If the launch itself fails, reap the watchdog: otherwise it would later kill the tag
# and inject a spurious TIMEOUT for an agent that never started.
if ! "${cmd[@]}"; then
  kill "$watchdog_pid" >/dev/null 2>&1 || true
  rm -f "$wd_pid_file"
  ma_log_event "$run_dir" dispatch_failed "role=$role task=$task_id"
  ma_die "launch failed for role=$role task=$task_id"
fi
printf 'DISPATCHED role=%s task=%s artifact=%s timeout=%s\n' "$role" "$task_id" "$artifact" "$timeout_s"
