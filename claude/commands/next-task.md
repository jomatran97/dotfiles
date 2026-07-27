# /next-task

Context hygiene checkpoint:

1. Resolve the current run yourself — slash commands are NOT placeholder-rendered:
   `RUN_DIR="$MULTIAGENT_RUNS/run-$(cat "$MULTIAGENT_RUNS/CURRENT")"`.
2. Distill the current phase/task, decisions, risks, and next action into `$RUN_DIR/state.md`.
3. Ensure `PLAN_SCRUM.md` statuses are current.
4. Run `hcom list` and note active tags.
5. `/clear` if needed, then re-prime from `state.md`, `PLAN_SCRUM.md`, and active hcom status.
6. Continue with the next pending task or finalization.
