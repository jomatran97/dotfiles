# Arbiter dotfiles workspace

This repository contains an Arbiter-managed workspace for coordinating multiple AI coding providers while keeping each provider's configuration isolated.

## Engineering doctrine

Arbiter treats agent execution as governed workflow infrastructure, not opaque automation.

- Gates and persisted state decide truth.
- Structured artifacts and manifests carry workflow memory.
- CLI inspection is part of the feature, not an afterthought.
- New orchestration work should fail closed, stay machine-readable, and ship with tests plus docs.

See `arbiter/DOCTRINE.md` for the full operating doctrine.

## Research record

Research documents exist under `research/`:

- `research/claude.md`
- `research/codex.md`
- `research/antigravity.md`

Provider-specific source-of-truth workspaces:

- `claude/`
- `codex/`
- `antigravity/`

Provider adapter implementations now live under `providers/` and are accessed through the Arbiter CLI.

Requirements document:

- `arbiter/REQUIREMENTS.md`

Design document:

- `arbiter/DESIGN.md`

Maintenance document:

- `arbiter/MAINTENANCE.md`

Engineering doctrine:

- `arbiter/DOCTRINE.md`

Deployment document:

- `arbiter/DEPLOYMENT.md`

Testing document:

- `arbiter/TESTING.md`

## Install / bootstrap

This repo is organized as XDG-style config directories rather than root-level dotfiles.

Typical setup:

```sh
ln -s "$(pwd)/zsh" ~/.config/zsh
ln -s "$(pwd)/tmux" ~/.config/tmux
ln -s "$(pwd)/nvim" ~/.config/nvim
ln -s "$(pwd)/ghostty" ~/.config/ghostty
ln -s "$(pwd)/git" ~/.config/git
ln -s "$(pwd)/yabai" ~/.config/yabai
ln -s "$(pwd)/skhd" ~/.config/skhd
ln -s "$(pwd)/sketchybar" ~/.config/sketchybar
```

Tool-specific follow-up steps:

- zsh plugins: the repo vendors plugin checkouts under `zsh/plugins/`; if you intentionally remove them, restore missing ones with `zsh -ic 'source ~/.config/zsh/plugins.zsh && zplugin-install'`
- shell extras: `brew install atuin bat eza fd fzf mise starship zoxide`
- tmux plugins: the repo vendors plugin checkouts under `tmux/plugins/` (including TPM), so a normal symlinked install works out of the box; press `Ctrl+A` then `I` inside tmux only when you want TPM to reinstall or update plugins
- Neovim plugins/tooling: launch `nvim` and let lazy.nvim + Mason bootstrap
- Git extras: `brew install git-delta difftastic`; then run `git maintenance start`
- terminal app: install Ghostty separately from https://ghostty.org/download and symlink `ghostty/`
- macOS window management/bar deps: `brew tap asmvik/formulae && brew tap FelixKratz/formulae && brew install asmvik/formulae/yabai asmvik/formulae/skhd FelixKratz/formulae/sketchybar`
- macOS services: start window manager daemons with `yabai --start-service` and `skhd --start-service`; start the bar with `brew services start sketchybar`
- macOS permissions: grant Accessibility to `yabai` and `skhd` in System Settings → Privacy & Security → Accessibility
- SketchyBar spaces: the starter predeclares spaces 1-6 to match yabai + skhd and hides any that do not currently exist; if you expand the setup, update `SPACE_COUNT` in `yabai/yabairc`, the space bindings in `skhd/skhdrc`, and `SPACES=` in `sketchybar/sketchybarrc` together
- Optional advanced yabai features: this starter avoids scripting-addition-only commands, so no SIP changes are required for the core workflow

Arbiter/provider assets are installed separately through the commands documented below.

## Directory map

- `arbiter/` — Arbiter coordination assets.
- `claude/` — Claude Code settings, agents, skills, hooks, MCP assets, and `CLAUDE.md`.
- `codex/` — Codex config, prompts, agents, and templates.
- `antigravity/` — Antigravity settings, agents, prompts, and artifacts.
- `providers/` — provider adapter implementations for Claude, Codex, and Antigravity.
- `research/` — permanent platform research documentation.
- `ghostty/`, `git/`, `nvim/`, `sketchybar/`, `skhd/`, `tmux/`, `yabai/`, `zsh/` — active user application configs managed from this repo.
- `state/` — runtime state, not secrets.
- `logs/` — runtime logs.
- `scripts/` — operational entrypoints such as `scripts/arbiter` and `scripts/test-arbiter`.

## Arbiter CLI

Run Arbiter with:

```sh
./scripts/arbiter check-gates
./scripts/arbiter providers
./scripts/arbiter doctor
./scripts/arbiter workflow-state --json
./scripts/arbiter workflow-artifacts <goal-id> --json
./scripts/arbiter workflow-artifacts <goal-id> --selection-only --phase RESEARCH --json
./scripts/arbiter workflow-artifacts <goal-id> --summary
./scripts/arbiter workflow-artifacts <goal-id> --summary --sort-by newest
./scripts/arbiter workflow-artifacts <goal-id> --active-only --sort-by newest --limit 3 --json
./scripts/arbiter workflow-artifacts <goal-id> --selection-only --summary --limit 1
./scripts/arbiter workflow-run testing --json
./scripts/arbiter materialize claude --json
./scripts/arbiter plan codex --prompt "Explain this workspace"
./scripts/arbiter run codex --agent build --prompt "Explain this workspace" --json
```

`workflow-run` advances the repository phase machine and gates.
Live specialist-agent execution is explicit through `hcom send` and `run --agent ...`, both of which enforce exact registry mappings. `workflow-run` now also attempts mapped specialist dispatch and persists per-phase handoff artifacts, but the repository phase gates remain authoritative unless `ARBITER_REQUIRE_PHASE_AGENTS=1` is set.

`materialize` defaults to dry-run. Use `--write` only when you want Arbiter to create runtime config under `state/`.

Run tests with:

```sh
./scripts/test-arbiter
./tests/harness.sh
```

## Global provider config installer

Dry-run the global installer first:

```sh
./scripts/install-global-provider-config --dry-run
./scripts/install-global-provider-config --force
./scripts/install-global-provider-config --backup-dir ./state/backups/manual-install --force
```

The installer copies vetted source-of-truth assets from `claude/`, `codex/`, and `antigravity/` into official user/global locations. It skips overwriting existing files unless `--force` is set, makes backups before overwriting files it actually changes, avoids obvious secret/auth files, warns and skips file targets whose destination path is a directory or non-restorable symlink, validates parent path components before `mkdir -p` so one bad path only skips that target, and prints a summary of actions, warnings, and skips.

Antigravity is handled conservatively because it writes shared global Gemini state under `~/.gemini/...`. The installer warns on those paths, preserves existing shared `settings.json`, `hooks.json`, and `mcp_config.json` files even with `--force` until a schema-aware merge exists, and skips ambiguous Antigravity mappings instead of guessing schema.

## Mandatory exact agent mappings

- `scout/ideas/craft/trace -> Antigravity`
- `build/debug -> GPT-5.5 Codex`
- `audit -> Claude Opus 4.8`
- `Arbiter -> Claude Sonnet`

Internal provider ids remain unchanged in code and HCOM payloads (`antigravity`, `gpt-5.5-codex`, `claude-opus-4.8`, `claude-sonnet-4`).

Startup validation fails closed if these registry or markdown mappings drift, or if a non-authoritative prompt file tries to redefine a registered agent.

## Gate

Design has been approved. Implementation and local tests are complete for the initial Arbiter Python CLI and provider adapters.

Arbiter now also persists workflow phase state plus enforced reflection/escalation checkpoints under `state/arbiter/workflow/`, requires explicit checkpoint evidence artifacts under `state/arbiter/workflow/checkpoints/<goal-id>/`, writes verify/audit artifacts as `state/arbiter/workflow/verify-result.json` and `state/arbiter/workflow/audit-result.json`, updates the `TODO.md` workflow section automatically when a workflow goal runs, persists specialist phase handoffs under `state/arbiter/workflow/phase-artifacts/<goal-id>/<phase>.json`, writes a per-goal handoff manifest at `state/arbiter/workflow/phase-artifacts/<goal-id>/index.json`, archives low-value duplicate handoffs under `state/arbiter/workflow/phase-artifacts/<goal-id>/archive/`, and exposes `workflow-state`, `workflow-artifacts`, `workflow-run`, and `workflow-checkpoint complete` CLI commands for repository-phase orchestration.
