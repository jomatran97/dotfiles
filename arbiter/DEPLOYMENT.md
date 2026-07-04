# Arbiter Deployment

Status: local deployment plan for this dotfiles repository.

## Deployment model

Arbiter is currently a local Python package in this repository. It uses only the Python standard library and can be run directly through:

```sh
./scripts/arbiter --help
```

No package installation is required.

Today `workflow-run` is a repository-phase state machine and gate runner. It now also attempts mapped specialist-agent dispatch and persists per-phase handoff artifacts. Live specialist-agent execution remains explicit through `hcom send` or `run --agent ...`, both of which enforce the checked-in registry mappings. Set `ARBITER_REQUIRE_PHASE_AGENTS=1` if you want phase-agent failures to fail the workflow run.

## Preconditions

Before using Arbiter:

1. Research gate files must exist:
   - `research/claude.md`
   - `research/codex.md`
   - `research/antigravity.md`
2. Requirements and Design documents must exist:
   - `arbiter/REQUIREMENTS.md`
   - `arbiter/DESIGN.md`
3. Testing and deployment prerequisites should pass:
   - `./scripts/test-arbiter`
   - `./tests/harness.sh`
4. Provider CLIs should be installed only if you intend to run that provider:
   - Claude Code: `claude`
   - OpenAI Codex: `codex`
   - Google Antigravity: discovered from `AGY_BIN`, `agy`, `antigravity`, or `antigravity-cli`

## Safe first run

```sh
./scripts/arbiter check-gates
./scripts/arbiter workflow-state --json
./scripts/arbiter workflow-artifacts <goal-id> --json
./scripts/arbiter workflow-artifacts <goal-id> --active-only --phase RESEARCH --json
./scripts/arbiter workflow-artifacts <goal-id> --summary
./scripts/arbiter workflow-artifacts <goal-id> --summary --sort-by status
./scripts/arbiter workflow-artifacts <goal-id> --archived-only --sort-by oldest --limit 5 --json
./scripts/arbiter workflow-run testing --json
./scripts/arbiter providers
./scripts/arbiter doctor
./scripts/arbiter materialize claude --json
./scripts/arbiter materialize codex --json
./scripts/arbiter materialize antigravity --json
```

The materialization commands above are dry-runs and do not write provider config.

## Runtime writes

When `--write` is used, Arbiter writes runtime materialization files under `state/` only. It does not write global provider config.

Workflow runtime persistence is stored under `state/arbiter/workflow/`.

- `state/arbiter/workflow/state.json`: persisted workflow state.
- `state/arbiter/workflow/queue.json`: active and pending workflow goals.
- `state/arbiter/workflow/history.jsonl`: append-only workflow history.
- `state/arbiter/workflow/state.json` also records enforced reflection/escalation checkpoints and their completion status.
- `state/arbiter/workflow/verify-result.json`: structured verification artifact written by the verify phase.
- `state/arbiter/workflow/audit-result.json`: structured audit artifact written by the audit phase.

The deployment gate now requires a passing `state/arbiter/workflow/audit-result.json` artifact plus successful `scripts/test-arbiter` and `tests/harness.sh` runs. The audit artifact itself fails closed unless `state/arbiter/workflow/verify-result.json` is present and passing. When a mapped provider is ready, `workflow-run` also persists specialist-agent handoff artifacts under `state/arbiter/workflow/phase-artifacts/<goal-id>/<phase>.json`, writes a per-goal index at `state/arbiter/workflow/phase-artifacts/<goal-id>/index.json`, and archives low-value duplicate handoffs under `state/arbiter/workflow/phase-artifacts/<goal-id>/archive/`. A workflow log at `logs/arbiter/workflow.jsonl` is no longer sufficient for deployment approval.

Workflow queue and state persistence use cross-process locking and atomic file replacement so concurrent enqueues do not lose queued goals.

Provider isolation variables:

- Claude adapter sets `CLAUDE_CONFIG_DIR` to `state/claude/config` in command plans.
- Codex adapter sets `CODEX_HOME` to `state/codex/home` in command plans.
- Antigravity adapter stages shadow config under `state/antigravity/shadow-config/<run-id>` and does not mutate `~/.gemini`.

## Recovery

If the workflow escalates, subsequent `workflow-run` commands keep failing until you clear the escalated state explicitly:

```sh
./scripts/arbiter workflow-reset --json
```

`workflow-reset` clears the escalated workflow state and preserves the persisted phase history so a new forward-only goal can be enqueued safely.

## Provider binary overrides

Use these environment variables to point Arbiter at non-standard binaries:

```sh
CLAUDE_BIN=/path/to/claude ./scripts/arbiter doctor claude
CODEX_BIN=/path/to/codex ./scripts/arbiter doctor codex
AGY_BIN=/path/to/agy ./scripts/arbiter doctor antigravity
```

## Rollback

Arbiter runtime state can be removed safely if no provider process is running:

```sh
rm -rf state/arbiter state/claude state/codex state/antigravity
rm -rf logs/arbiter logs/claude logs/codex logs/antigravity
```

Do not remove provider-native global config through Arbiter rollback commands; Arbiter does not create or own those files by default.
