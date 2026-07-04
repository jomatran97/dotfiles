# Arbiter Requirements

Status: Requirements phase draft created after Phase 0 research approval.

This document defines what Arbiter must do before Design and Implementation. It intentionally avoids implementation details and source code.

## 1. Goals

Arbiter coordinates multiple AI coding providers while keeping each provider isolated and replaceable.

Target providers:

- Claude Code
- OpenAI Codex
- Google Antigravity

Primary goals:

1. Maintain isolated provider workspaces.
2. Launch and manage provider processes through provider adapters only.
3. Normalize provider communication through HCOM.
4. Preserve provider-native configuration models.
5. Avoid leaking secrets or cross-contaminating provider state.
6. Support repeatable setup from this dotfiles repository.

## 2. Non-goals

Arbiter must not:

- Reimplement Claude Code, Codex, or Antigravity internals.
- Store provider authentication tokens in this repository.
- Mix provider configuration files across provider workspaces.
- Write to global provider configuration paths without explicit adapter control and backup/merge behavior.
- Bypass provider permission systems by default.
- Generate implementation code before Requirements and Design are accepted.

## 3. Workspace requirements

### ARB-REQ-001: Provider isolation

Each provider must have an isolated source-of-truth workspace:

- `claude/`
- `codex/`
- `antigravity/`

Provider-specific prompts, settings templates, agents, skills, MCP assets, hooks, artifacts, and integration metadata must remain under the relevant provider directory.

### ARB-REQ-002: Runtime state separation

Runtime state must be separated from source templates:

- Shared runtime state: `state/`
- Logs: `logs/`
- Provider runtime state should use provider-specific subdirectories such as `state/claude/`, `state/codex/`, and `state/antigravity/`.

### ARB-REQ-003: Research gate enforcement

Arbiter must treat these files as mandatory prerequisites:

- `research/claude.md`
- `research/codex.md`
- `research/antigravity.md`

If any are missing, workflows after Bootstrap/Research must fail closed.

### ARB-REQ-004: Idempotent bootstrap

Bootstrap scripts or commands must be safe to run repeatedly. Existing provider assets must not be overwritten without explicit intent.

## 4. Provider adapter requirements

Each provider must be accessed only through its adapter:

- `providers/claude/`
- `providers/codex/`
- `providers/antigravity/`

### ARB-REQ-010: Adapter boundary

The Arbiter core must not directly invoke provider CLIs or mutate provider config. All provider-specific behavior must be encapsulated in the relevant adapter.

### ARB-REQ-011: Process startup

Each adapter must support:

- CLI discovery.
- Version detection.
- Capability detection.
- Interactive launch where supported.
- Non-interactive/headless launch where supported.
- Working-directory selection.
- Environment construction.
- Graceful shutdown.
- Forced termination as a fallback.

### ARB-REQ-012: Authentication handling

Adapters must detect authentication readiness without storing secrets in the repository.

Adapters may use:

- Existing provider login state.
- Environment variables.
- OS keychain/credential store.
- User-approved external secret managers.

Adapters must report missing authentication as a structured readiness error.

### ARB-REQ-013: Configuration loading

Adapters must load provider configuration from Arbiter-controlled source directories and materialize provider-native runtime configuration only through documented provider mechanisms.

### ARB-REQ-014: HCOM communication

Adapters must expose a provider-neutral HCOM interface for:

- Sending tasks/prompts.
- Receiving streamed or final output.
- Reporting tool calls and approvals when observable.
- Reporting lifecycle state.
- Reporting errors.
- Capturing artifacts.

### ARB-REQ-015: Lifecycle management

Adapters must model provider sessions with lifecycle states:

- `uninitialized`
- `ready`
- `starting`
- `running`
- `waiting_for_auth`
- `waiting_for_permission`
- `completed`
- `failed`
- `stopping`
- `stopped`

## 5. Claude Code requirements

### ARB-CLAUDE-001: Native configuration preservation

The Claude adapter must preserve Claude Code's official configuration model:

- `CLAUDE.md`
- `.claude/settings.json`
- `.claude/settings.local.json`
- `.claude/agents/*.md`
- `.claude/skills/<name>/SKILL.md`
- `.claude/hooks/`
- `.mcp.json`
- `CLAUDE_CONFIG_DIR` for isolated user/global state when required.

### ARB-CLAUDE-002: Safe default permissions

The Claude adapter must default to non-bypass permission modes. `bypassPermissions` or `--dangerously-skip-permissions` must require explicit configuration.

### ARB-CLAUDE-003: MCP and hooks

Claude MCP servers and hooks must be configured using Claude-native settings and `.mcp.json` formats. Secrets must be injected from environment or external secret sources, not committed files.

## 6. Codex requirements

### ARB-CODEX-001: Native configuration preservation

The Codex adapter must preserve Codex's official configuration model:

- `$CODEX_HOME/config.toml`
- `$CODEX_HOME/<profile>.config.toml`
- Project `.codex/config.toml`
- `AGENTS.md`
- `.agents/skills`
- `$CODEX_HOME/hooks.json`
- Project `.codex/hooks.json`
- `mcp_servers` configuration.

### ARB-CODEX-002: Isolated CODEX_HOME

The Codex adapter must support `CODEX_HOME` isolation under Arbiter runtime state.

### ARB-CODEX-003: Trust-aware project config

The Codex adapter must respect Codex project trust behavior. Project-local `.codex/` config, hooks, and rules must not be assumed active unless the project is trusted.

### ARB-CODEX-004: Safe sandbox defaults

Codex must default to a safe sandbox/approval combination such as workspace-write with approvals, unless explicitly configured otherwise.

## 7. Antigravity requirements

### ARB-AGY-001: Version-discovered behavior

Because Antigravity documentation was partially client-rendered during research, the Antigravity adapter must discover exact CLI capabilities from the installed CLI before enabling features.

### ARB-AGY-002: Native configuration preservation

The Antigravity adapter must preserve Antigravity/Gemini shared configuration behavior. Observed official paths include:

- `~/.gemini/antigravity-cli/settings.json`
- `~/.gemini/config/projects/`
- `~/.gemini/config/hooks.json`
- `~/.gemini/config/`
- `~/.gemini/antigravity-cli/cache/`

The adapter must not directly mutate shared global config without backup/merge strategy and explicit user approval.

### ARB-AGY-003: Artifact capture

Antigravity artifacts and exported/reviewed outputs must be captured into either:

- `antigravity/artifacts/` for source-controlled/reference artifacts, or
- `state/antigravity/artifacts/` for runtime outputs.

### ARB-AGY-004: Permission safety

The Antigravity adapter must respect native permission and sandbox behavior. Global/shared permissions must not be loosened without explicit user approval.

## 8. Security requirements

### ARB-SEC-001: No secrets in repository

The repository must not contain provider tokens, OAuth refresh tokens, API keys, keychain exports, `.env` secrets, or provider auth cache files.

### ARB-SEC-002: Explicit trust boundaries

Adapters must distinguish:

- Repository source templates.
- Runtime-generated config.
- Provider global/user config.
- Provider project config.
- Secrets.

### ARB-SEC-003: Deny unsafe modes by default

Dangerous modes such as permission bypass, full-access sandboxes, global write access, or unreviewed shared settings updates must be opt-in.

### ARB-SEC-004: Logs must be scrub-friendly

Logs must be centralized under `logs/` and structured enough to support future secret scrubbing.

## 9. Observability requirements

Arbiter must record:

- Provider selected.
- Adapter version/capabilities.
- Provider CLI version.
- Session lifecycle transitions.
- Working directory.
- Config materialization paths.
- HCOM message IDs.
- Exit codes and error summaries.

Sensitive payloads must be redacted or avoidably not logged.

## 10. Testing requirements

Minimum test coverage after implementation:

- Research gate missing-file failure.
- Workspace bootstrap idempotence.
- Provider CLI discovery failure.
- Authentication-not-ready handling.
- Config materialization dry run.
- Process startup command construction without execution.
- HCOM request/response normalization.
- Safe default permission modes.
- Provider isolation checks to prevent cross-provider config writes.

## 11. Acceptance criteria for Requirements phase

Requirements phase is complete when:

- This document exists at `arbiter/REQUIREMENTS.md`.
- Provider-specific requirements are captured for Claude, Codex, and Antigravity.
- Security, isolation, lifecycle, HCOM, and testing requirements are captured.
- No implementation source code has been generated.

## 12. Open items for Design

Design must define:

- HCOM message schema.
- Adapter interfaces.
- Runtime directory layout.
- Config materialization strategy.
- CLI capability detection strategy.
- Secret injection strategy.
- Logging/event schema.
- Test plan and fixtures.
