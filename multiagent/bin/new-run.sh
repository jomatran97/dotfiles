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
mkdir -p "$MULTIAGENT_RUNS"
run_id=$(date '+%Y%m%d-%H%M%S')-$$
run_dir="$MULTIAGENT_RUNS/run-$run_id"
mkdir -p "$run_dir/context"
printf '%s\n' "$PWD" > "$run_dir/project_dir"
cat > "$run_dir/task.md" <<EOF
# Task

Goal: ${goal:-TODO: replace with the user goal.}

Created: $(ma_ts)
Project directory: $PWD

## Constraints

- Follow the multiagent charter.
- Keep secrets and runtime state out of the dotfiles repo.
EOF
cat > "$run_dir/state.md" <<EOF
# State

Run: $run_id
Project: $PWD
Status: initialized
Updated: $(ma_ts)
EOF
cat > "$run_dir/PLAN_SCRUM.md" <<EOF
# PLAN_SCRUM

## Goal
${goal:-TODO}

## Task Ledger

| ID | Status | Owner | Summary | Attempts | Notes |
| --- | --- | --- | --- | --- | --- |

## Decisions

## Backtracking Log

## Done Criteria

EOF
: > "$run_dir/run.jsonl"
printf '%s\n' "$run_id" > "$MULTIAGENT_RUNS/CURRENT"
ma_log_event "$run_dir" new_run "run_id=$run_id project=$PWD goal=${goal:-}"
printf 'RUN_ID=%s\nRUN_DIR=%s\n' "$run_id" "$run_dir"
