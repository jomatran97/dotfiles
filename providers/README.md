# Provider adapter workspace

This directory now contains the live Arbiter provider adapter implementations:

- `providers/base.py`
- `providers/registry.py`
- `providers/claude/adapter.py`
- `providers/codex/adapter.py`
- `providers/antigravity/adapter.py`

The checked-in provider-specific source-of-truth configuration assets still live in their dedicated workspaces:

- `claude/`
- `codex/`
- `antigravity/`

Use `./scripts/arbiter providers`, `./scripts/arbiter materialize <provider>`, and `./scripts/install-global-provider-config --dry-run` to inspect or install the repo-managed provider assets.
