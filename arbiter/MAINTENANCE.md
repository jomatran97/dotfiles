# Arbiter Maintenance

## Routine checks

Run before provider changes:

```sh
./scripts/test-arbiter
./scripts/arbiter check-gates
./scripts/arbiter doctor
```

## Updating provider behavior

When Claude Code, Codex, or Antigravity changes CLI/config behavior:

1. Update the relevant `research/*.md` document with official documentation references.
2. Update `arbiter/REQUIREMENTS.md` if behavior changes requirements.
3. Update `arbiter/DESIGN.md` if adapter boundaries or runtime layout change.
4. Update adapter tests with fake CLI behavior.
5. Run the full test suite.

## Adding provider features

Feature additions should follow this order:

1. Add/adjust tests using fake provider CLIs.
2. Add dry-run command planning or materialization support.
3. Add logging/redaction for new event fields.
4. Add opt-in live execution behavior.
5. Document new usage in `README.md` and this file.

## Security maintenance

- Never commit provider auth files or tokens.
- Keep `state/` and `logs/` ignored except their placeholder directories.
- Treat provider stdout/stderr as potentially sensitive.
- Prefer dry-runs before writes.
- Keep Antigravity shared config mutation disabled unless a future implementation adds explicit backup/merge/approval support.

## Troubleshooting

Provider not found:

```sh
./scripts/arbiter providers
CLAUDE_BIN=/custom/path/claude ./scripts/arbiter doctor claude
CODEX_BIN=/custom/path/codex ./scripts/arbiter doctor codex
AGY_BIN=/custom/path/agy ./scripts/arbiter doctor antigravity
```

Gate failure:

```sh
./scripts/arbiter check-gates --json
```

Config materialization review:

```sh
./scripts/arbiter materialize claude --json
./scripts/arbiter materialize codex --json
./scripts/arbiter materialize antigravity --json
```
