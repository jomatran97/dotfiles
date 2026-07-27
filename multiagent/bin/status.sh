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

role=${1:-}; task_id=${2:-global}
[ -n "$role" ] || ma_die "usage: ma-status <role> [task-id]"
run_dir=$(ma_current_run_dir) || ma_die "no current run"
artifact_rel=$(ma_artifact_for "$role" "$task_id")
artifact="$run_dir/$artifact_rel"
done_flag="$artifact.done"
printf 'role=%s task=%s run_dir=%s\n' "$role" "$task_id" "$run_dir"
printf 'artifact=%s\n' "$artifact"
if [ -f "$done_flag" ]; then printf 'done=yes done_flag=%s\n' "$done_flag"; else printf 'done=no done_flag=%s\n' "$done_flag"; fi
if [ -f "$artifact" ]; then printf 'artifact_exists=yes bytes=%s\n' "$(wc -c < "$artifact" | tr -d ' ')"; else printf 'artifact_exists=no\n'; fi
if ma_have hcom; then printf -- '--- hcom list ---\n'; hcom list 2>&1 | sed -n '1,80p' || true; else printf 'hcom=missing\n'; fi
