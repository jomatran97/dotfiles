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
if [ -n "$goal" ] || ! ma_current_run_dir >/dev/null 2>&1; then
  "$DOTFILES/multiagent/bin/new-run.sh" "$goal"
fi
run_dir=$(ma_current_run_dir) || ma_die "no current run"
role_file=$(ma_role_file architect)
role_text=$(ma_render_text "$(ma_strip_frontmatter "$role_file")" "$run_dir" global)
prompt=$(cat <<EOF
Start the Chief Architect orchestration loop for RUN_DIR=$run_dir.
Read task.md, project_dir, state.md, and PLAN_SCRUM.md. Use ma-dispatch and ma-status. Do not run long hcom events waits inside this interactive session.
EOF
)
if ! ma_have hcom; then ma_die "hcom not found; cannot launch architect"; fi
hcom kill tag:architect >/dev/null 2>&1 || true
cmd=(hcom claude --tag architect --terminal tmux --permission-mode acceptEdits --add-dir "$run_dir" --settings "$DOTFILES/claude/architect.settings.json" --hcom-system-prompt "$role_text" --hcom-prompt "$prompt")
model=$(ma_yaml_field "$role_file" model || true); model=${model:-default}
if [ "$model" != "default" ] && [ -n "$model" ]; then cmd+=(--model "$model"); fi
# architect.settings.json grants Read only under /Users/ryanparker/Documents/personal/code/**;
# a project outside that tree is unreadable to the headless architect (prompts auto-deny).
proj_check=$(sed -n '1p' "$run_dir/project_dir" 2>/dev/null || true)
case "$proj_check" in
  /Users/ryanparker/Documents/personal/code/*) : ;;
  *) printf 'WARN project %s is outside the Read scope in claude/architect.settings.json — headless reads of it will be denied\n' "$proj_check" >&2 ;;
esac
ma_log_event "$run_dir" architect_launch "interactive tag=architect"
"${cmd[@]}"
