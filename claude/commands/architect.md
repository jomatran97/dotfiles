# /architect

Start or resume the multiagent orchestration loop for the current run.

1. Resolve the current run yourself — slash commands are NOT placeholder-rendered:
   `RUN_DIR="$MULTIAGENT_RUNS/run-$(cat "$MULTIAGENT_RUNS/CURRENT")"` (or run `ma-status architect`).
2. Read `$RUN_DIR/task.md`, `$RUN_DIR/state.md`, `$RUN_DIR/PLAN_SCRUM.md` if present, and `hcom list`.
3. Follow the Chief Architect role in `claude/agents/architect.md`.
4. Dispatch workers with `ma-dispatch`, poll with `ma-status`, and never block on long `hcom events --wait` calls inside interactive Claude.
