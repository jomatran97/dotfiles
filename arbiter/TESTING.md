# Arbiter Testing

Status: implemented and passing with standard-library `unittest`.

## Test command

```sh
./scripts/test-arbiter
./tests/harness.sh
```

Equivalent command:

```sh
PYTHONPATH="$PWD" python3 -m unittest discover -s tests
```

## Current coverage

The current test suite covers:

- Research/Requirements/Design gate checks.
- HCOM envelope serialization and validation.
- Detached HCOM session start/kill lifecycle, including same-process reaping and session-store cleanup.
- Claude config materialization dry-runs.
- Codex config materialization writes into isolated `state/codex/home`.
- Antigravity shadow-config behavior.
- Fake Claude CLI discovery, auth status, and command planning.
- Fake Codex CLI discovery, auth status, safe sandbox/approval defaults, and dangerous-mode rejection.
- Fake Antigravity CLI capability failure when headless print mode is not detected.
- Workflow state transitions, enforced reflection/escalation checkpoints, TODO updates, deployment gating, verify/audit runtime artifacts, manifest-backed workflow-artifact inspection (filters, sorting, summary mode, limits), stale-goal rejection, escalated reset behavior, CLI inspection/run/reset flows, and concurrent enqueue locking regression coverage.

## Compile check

```sh
python3 -m compileall -q arbiter providers tests
```

## Smoke checks

```sh
./scripts/arbiter check-gates
./scripts/arbiter workflow-state --json
./scripts/arbiter workflow-artifacts <goal-id> --summary --limit 1
./scripts/arbiter workflow-artifacts <goal-id> --selection-only --summary --sort-by newest
./scripts/arbiter workflow-run testing --json
./scripts/arbiter workflow-reset --json
./scripts/arbiter materialize claude --json
./scripts/arbiter plan codex --prompt "Explain this workspace"
```

`materialize` is dry-run by default. Use `--write` only when you want runtime config generated under `state/`.

`tests/harness.sh` provisions a fake Codex executable and fails closed on HCOM regressions instead of masking provider launch errors.

## Integration testing

Integration tests against real provider CLIs are intentionally opt-in because they may require local authentication and provider-specific state.

Recommended manual checks:

```sh
./scripts/arbiter doctor claude
./scripts/arbiter doctor codex
./scripts/arbiter doctor antigravity
```

If a provider is not installed, `doctor` should fail with a structured readiness error rather than mutating config.
