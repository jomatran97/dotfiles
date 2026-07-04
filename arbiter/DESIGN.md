# Arbiter Design

Status: Design phase draft created after Requirements approval.

This document defines the architecture and implementation plan boundaries for Arbiter. It is a design artifact only; no implementation/source code is included.

## 1. Design objectives

Arbiter coordinates Claude Code, OpenAI Codex, and Google Antigravity through provider adapters while preserving each provider's native configuration model.

Design objectives:

1. Keep provider configuration isolated.
2. Make runtime state reproducible and inspectable.
3. Use provider-native CLIs and documented configuration mechanisms.
4. Normalize communication through HCOM.
5. Fail closed when research, auth, config, or capability checks are incomplete.
6. Avoid secrets in repository files and logs.
7. Support dry-run validation before any provider-global config mutation.

## 2. System architecture

Arbiter is composed of these conceptual components:

| Component | Responsibility |
| --- | --- |
| Arbiter Core | Coordinates sessions, selects providers, enforces gates, owns HCOM routing. |
| Provider Registry | Knows available adapters and their capability summaries. |
| Workspace Manager | Creates runtime workspaces, state directories, and log directories. |
| Config Materializer | Converts source-of-truth provider assets into provider-native runtime config. |
| Secret Resolver | Reads approved secret references from environment/keychain/external secret manager; never writes secrets to repo. |
| Process Supervisor | Starts, monitors, stops, and force-kills provider processes. |
| HCOM Bus | Normalizes provider input/output and lifecycle events. |
| Artifact Collector | Captures provider artifacts into provider-specific artifact/state paths. |
| Audit Logger | Writes structured events to `logs/` with redaction. |

Adapters are the only layer allowed to understand provider-specific CLI flags, environment variables, config paths, and behavior.

## 3. Repository and runtime layout

### 3.1 Source-of-truth repository layout

Existing repository directories remain source templates and documentation:

```text
arbiter/                  Design, requirements, future core assets
providers/                Future provider adapter implementations
claude/                   Claude Code source templates
codex/                    Codex source templates
antigravity/              Antigravity source templates and durable artifacts
research/                 Permanent research docs
state/                    Runtime state root
logs/                     Runtime logs root
scripts/                  Future operational scripts
```

### 3.2 Runtime layout

The design uses provider-specific runtime directories under `state/`:

```text
state/
  arbiter/
    runs/<run-id>/
    materializations/<materialization-id>/
    capabilities/
  claude/
    config/               Used as CLAUDE_CONFIG_DIR when isolation is enabled
    workspaces/<run-id>/
    artifacts/<run-id>/
  codex/
    home/                 Used as CODEX_HOME
    workspaces/<run-id>/
    artifacts/<run-id>/
  antigravity/
    shadow-config/        Staged config before user-approved merge
    workspaces/<run-id>/
    artifacts/<run-id>/
```

Logs are provider-separated:

```text
logs/
  arbiter/
  claude/
  codex/
  antigravity/
```

### 3.3 Immutable run identity

Every provider execution receives a `run-id`. The `run-id` is used in:

- HCOM envelopes.
- Log filenames.
- Runtime workspace paths.
- Materialization manifests.
- Artifact paths.

A run must be reproducible from:

- Provider name.
- Adapter version.
- Provider CLI version.
- Source template checksums.
- Materialized config manifest.
- Effective environment allowlist.
- Working directory.

## 4. Gate model

Arbiter has explicit gates:

1. Bootstrap.
2. Research.
3. Requirements.
4. Design.
5. Implementation.
6. Testing.
7. Deployment.
8. Maintenance.

### 4.1 Research gate

The Research gate passes only if all exist:

- `research/claude.md`
- `research/codex.md`
- `research/antigravity.md`

### 4.2 Requirements gate

The Requirements gate passes only if:

- `arbiter/REQUIREMENTS.md` exists.
- It contains provider, security, lifecycle, HCOM, observability, and testing requirements.

### 4.3 Design gate

The Design gate passes only if:

- `arbiter/DESIGN.md` exists.
- It defines adapter boundaries, HCOM schema, runtime layout, materialization strategy, and testing strategy.
- The user approves proceeding to Implementation.

Implementation remains blocked until this design is approved.

## 5. HCOM design

HCOM is the provider-neutral communication model between Arbiter Core and provider adapters.

### 5.1 Message envelope

Each HCOM message has these fields:

| Field | Meaning |
| --- | --- |
| `schema_version` | HCOM schema version. |
| `message_id` | Unique message identifier. |
| `correlation_id` | Links responses/events to originating request. |
| `run_id` | Arbiter run identifier. |
| `session_id` | Provider session identifier when known. |
| `timestamp` | UTC timestamp. |
| `source` | Sender: `arbiter`, `claude`, `codex`, `antigravity`, or adapter name. |
| `target` | Intended recipient. |
| `type` | Message type. |
| `payload` | Type-specific body. |
| `redaction` | Redaction metadata for logging. |

### 5.2 Message types

| Type | Direction | Purpose |
| --- | --- | --- |
| `session.prepare` | Arbiter to adapter | Request prerequisite checks and config materialization. |
| `session.ready` | Adapter to Arbiter | Provider is ready to start. |
| `session.start` | Arbiter to adapter | Start provider process/session. |
| `session.state` | Adapter to Arbiter | Lifecycle state transition. |
| `task.submit` | Arbiter to adapter | Submit a user task/prompt. |
| `output.delta` | Adapter to Arbiter | Streamed text or structured partial output. |
| `output.final` | Adapter to Arbiter | Final response for a task. |
| `tool.event` | Adapter to Arbiter | Observable tool call, command, MCP call, or file operation. |
| `permission.request` | Adapter to Arbiter | Provider requires approval. |
| `permission.response` | Arbiter to adapter | Approval/denial where provider supports external control. |
| `artifact.created` | Adapter to Arbiter | Artifact discovered or exported. |
| `error` | Any | Structured error. |
| `session.stop` | Arbiter to adapter | Graceful stop request. |
| `session.stopped` | Adapter to Arbiter | Provider stopped. |
| `metrics` | Adapter to Arbiter | Timings, exit codes, token/usage when available. |

### 5.3 Lifecycle states

Adapters report these normalized states:

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

Provider-specific substates may be included in payloads but must not replace normalized states.

### 5.4 Transport strategy

HCOM is transport-independent. Initial implementation should support:

1. In-process adapter calls for local orchestration.
2. Provider process stdout/stderr parsing when available.
3. JSON/JSONL output modes where providers officially support them.
4. Future external transports if Arbiter is split into separate processes.

Provider TUI screen scraping is not a preferred transport. It should be a last resort for human-observed sessions only.

## 6. Adapter contract design

Every provider adapter must implement the same conceptual operations:

| Operation | Description |
| --- | --- |
| Identify | Discover CLI path, version, and platform. |
| Probe capabilities | Detect supported flags, JSON modes, auth commands, sandbox options, model commands, MCP support. |
| Check readiness | Validate research gate, executable, auth state, config state, and workspace. |
| Prepare workspace | Create runtime directories for the run. |
| Materialize config | Generate provider-native runtime config from source templates. |
| Build environment | Construct environment variables without leaking secrets. |
| Build command | Produce command plan for interactive or non-interactive startup. |
| Start | Launch provider process/session. |
| Send | Send task or control message when supported. |
| Observe | Convert provider output/events into HCOM. |
| Stop | Gracefully stop provider. |
| Kill | Force termination fallback. |
| Collect artifacts | Move/copy/export artifacts into Arbiter paths. |
| Cleanup | Remove transient files according to retention policy. |

Adapters must support dry-run mode for Identify, Probe, Prepare, Materialize, Build environment, and Build command without launching a provider.

## 7. Config materialization design

### 7.1 Materialization principles

- Source templates are stored in provider directories.
- Runtime config is generated under `state/` or a temporary run workspace.
- Existing provider-global files are not overwritten directly.
- Every materialization writes a manifest containing source paths, destination paths, checksums, and actions.
- Secret values are represented by references, never copied into manifests.
- Destructive updates require explicit approval and backup.

### 7.2 Manifest contents

Each materialization manifest records:

- Materialization ID.
- Provider.
- Run ID.
- Timestamp.
- Source files and checksums.
- Destination files.
- Write mode: create, update, skip, backup, merge, or link.
- Secret references used.
- Validation results.
- Rollback instructions when applicable.

### 7.3 Template policy

Provider assets are plain provider-native files where possible. Arbiter templating should be minimal and limited to:

- Runtime paths.
- Enabled/disabled feature toggles.
- Environment variable references.
- Provider profile names.
- HCOM correlation identifiers.

Provider-native syntax must remain valid after rendering.

## 8. Secret and environment design

### 8.1 Secret sources

Allowed secret sources:

- Existing provider login state.
- Environment variables explicitly allowlisted for a run.
- OS keychain or credential store through provider-native mechanisms.
- User-approved external secret managers in future design extensions.

Disallowed secret storage:

- Repository files.
- Research docs.
- Requirements/design docs.
- Materialization manifests.
- Logs.

### 8.2 Environment construction

Adapters create a minimal provider environment:

- Required provider isolation variables, such as `CLAUDE_CONFIG_DIR` or `CODEX_HOME`.
- Provider-specific auth variables only when explicitly supplied.
- PATH and shell/toolchain variables needed for provider operation.
- HCOM/run metadata variables only if needed by hooks or scripts.

Adapters must redact environment values in logs unless a variable is explicitly classified as non-secret.

## 9. Provider-specific designs

## 9.1 Claude Code adapter design

### Discovery

The Claude adapter discovers:

- `claude` executable path.
- `claude --version` or equivalent version output.
- Availability of `claude auth status`.
- Availability of `claude -p` non-interactive mode.
- Availability of stream/JSON output flags for machine-readable output.
- Support for flags such as `--model`, `--permission-mode`, `--settings`, `--mcp-config`, `--add-dir`, and `--agent`.

### Runtime isolation

When isolation is enabled:

- Set `CLAUDE_CONFIG_DIR=state/claude/config`.
- Materialize project config into a run workspace.
- Keep auth out of repository templates.

### Config mapping

Source templates under `claude/` map to provider-native runtime paths:

| Source | Runtime target |
| --- | --- |
| `claude/CLAUDE.md` | `<workspace>/CLAUDE.md` or `<workspace>/.claude/CLAUDE.md` depending on design choice for the run. |
| `claude/settings/` | `<workspace>/.claude/settings.json` or adapter-composed settings. |
| `claude/agents/` | `<workspace>/.claude/agents/`. |
| `claude/skills/` | `<workspace>/.claude/skills/`. |
| `claude/hooks/` | `<workspace>/.claude/hooks/`. |
| `claude/mcp/` | `<workspace>/.mcp.json` or `--mcp-config` input. |

### Default safety

Default permission behavior must avoid bypass modes. Bypass requires explicit run config and must be logged as a high-risk setting.

### HCOM path

Preferred HCOM path:

1. Non-interactive `claude -p` with structured output if supported.
2. Plain stdout parsing for final output if structured output is unavailable.
3. Interactive TUI launch only for human-supervised sessions.

## 9.2 Codex adapter design

### Discovery

The Codex adapter discovers:

- `codex` executable path.
- CLI version.
- `codex login status` result.
- `codex exec --json` support.
- `codex doctor` availability.
- Supported sandbox and approval flags.
- MCP command support.
- App-server/remote support where relevant.

### Runtime isolation

Codex isolation uses:

- `CODEX_HOME=state/codex/home`.
- Provider sessions under `state/codex/workspaces/<run-id>/`.
- Logs under `logs/codex/`.

### Config mapping

| Source | Runtime target |
| --- | --- |
| `codex/config/` | `$CODEX_HOME/config.toml`, profile files, or project `.codex/config.toml`. |
| `codex/prompts/` | Prompt/template inputs passed to tasks or slash-command assets after design approval. |
| `codex/agents/` | Codex subagent or `.agents/` assets after capability verification. |
| `codex/templates/` | Materialization templates for Codex-native config. |

Codex project guidance maps to `AGENTS.md` and `.agents/skills` only when those assets exist and pass validation.

### Trust behavior

The adapter must detect or model whether a project is trusted. If trust is absent, the adapter must not assume `.codex/` config/hooks/rules are active.

### Default safety

Recommended default run policy:

- Workspace-write sandbox.
- On-request approvals.
- No full-access/yolo mode unless explicitly requested.

### HCOM path

Preferred HCOM path:

1. `codex exec --json` for non-interactive tasks.
2. `codex app-server` / remote protocol for richer future integration if stable and documented for the installed version.
3. Interactive TUI for human-supervised sessions.

## 9.3 Antigravity adapter design

### Discovery

Because Antigravity docs were partially unavailable as static text during research, Antigravity must be capability-probed before use.

Probe targets:

- Executable name and path, expected likely `agy` but not hardcoded.
- Version command.
- Help output.
- Model listing command if available.
- Headless print flags such as `-p` / `--print` if available.
- Conversation/resume flags such as `--conversation` / `-c` if available.
- Project flags such as `--project` and `--new-project` if available.
- Sandbox and permission flags.
- Settings, hooks, permissions, and artifact commands.

### Runtime isolation

Antigravity appears to share settings with Antigravity 2.0 under `~/.gemini/...`. Therefore the adapter design is conservative:

- Use `state/antigravity/shadow-config/` for staged config.
- Never mutate `~/.gemini/...` directly without backup, merge plan, and explicit user approval.
- Prefer provider-supported project flags and runtime options over global writes.
- Record all detected global paths in the materialization manifest.

### Config mapping

| Source | Runtime target |
| --- | --- |
| `antigravity/settings/` | Shadow settings first; official config paths only after approval and schema verification. |
| `antigravity/agents/` | Provider-native agent/plugin location only after capability verification. |
| `antigravity/prompts/` | Task prompt inputs or provider-native prompt assets after verification. |
| `antigravity/artifacts/` | Durable/source artifacts. Runtime artifacts go under `state/antigravity/artifacts/`. |

### Default safety

The adapter must not loosen shared permissions or sandbox behavior globally. Permission updates require explicit approval and backup.

### HCOM path

Preferred HCOM path:

1. Headless/print mode if installed CLI supports it.
2. Structured output if installed CLI supports it.
3. Artifact export/session export if available.
4. Interactive TUI for human-supervised sessions only.

## 10. Artifact design

Artifacts are separated by provider and run.

Artifact metadata includes:

- Artifact ID.
- Provider.
- Run ID.
- Source path or provider reference.
- MIME/type classification.
- Creation timestamp.
- Checksum.
- Whether artifact is durable/source-controlled or runtime-only.
- Redaction/sensitivity classification.

Default storage:

- Runtime artifacts: `state/<provider>/artifacts/<run-id>/`.
- Curated Antigravity source artifacts: `antigravity/artifacts/`.
- Future curated Claude/Codex artifacts should use provider-specific directories only if explicitly required.

## 11. Logging and observability design

### 11.1 Structured event log

Every run writes structured events under `logs/<provider>/` and `logs/arbiter/`.

Events include:

- Gate checks.
- Adapter discovery results.
- Capability probe results.
- Materialization actions.
- Lifecycle transitions.
- Process start/stop.
- HCOM messages or summaries.
- Errors.
- Artifact creation.

### 11.2 Redaction

Redaction applies to:

- API keys.
- OAuth tokens.
- Authorization headers.
- Cookie/session values.
- Provider auth cache paths when sensitive.
- Environment variable values unless non-secret.
- Tool output marked sensitive by adapter policy.

### 11.3 Diagnostics

Each adapter should support a diagnostic summary showing:

- Executable found/missing.
- Version.
- Auth readiness.
- Config validity.
- Dangerous-mode status.
- Last error.

## 12. Error design

Errors must be structured with:

- Error code.
- Provider.
- Phase.
- Human-readable summary.
- Recoverability.
- Suggested remediation.
- Original exit code or signal when applicable.
- Redacted diagnostic context.

Common error classes:

- `research_gate_failed`
- `requirements_gate_failed`
- `design_gate_failed`
- `cli_not_found`
- `version_unsupported`
- `auth_required`
- `config_invalid`
- `capability_missing`
- `permission_denied`
- `process_start_failed`
- `process_timeout`
- `provider_error`
- `artifact_collection_failed`

## 13. Testing design

Testing should be layered.

### 13.1 Unit tests

Unit tests validate:

- Gate checks.
- Path resolution.
- Materialization manifests.
- Environment construction and redaction.
- Command-plan generation.
- HCOM envelope validation.
- Lifecycle state transitions.
- Provider isolation rules.

### 13.2 Fake provider tests

Use fake provider CLIs/shims to simulate:

- Missing executable.
- Version output.
- Auth success/failure.
- JSON output.
- Permission prompts.
- Process failure.
- Artifact output.

Fake providers prevent unit tests from requiring real Claude/Codex/Antigravity installations.

### 13.3 Integration tests

Integration tests can be opt-in and require installed providers. They validate:

- CLI discovery.
- Auth status command behavior.
- Dry-run config materialization.
- Safe non-interactive smoke runs.
- Log and artifact paths.

Integration tests must not modify global provider config unless the test explicitly opts in and creates backups.

### 13.4 Security tests

Security tests validate:

- Secrets are not written to repo paths.
- Logs redact known secret patterns.
- Dangerous modes require explicit opt-in.
- Antigravity shared config mutation requires approval.
- Codex untrusted project config is not assumed active.
- Claude bypass permission mode is blocked by default.

## 14. Implementation sequencing after design approval

Implementation should proceed in small milestones:

1. Gate checker and workspace manager.
2. HCOM envelope and lifecycle event model.
3. Provider adapter dry-run framework.
4. Claude adapter discovery and dry-run config materialization.
5. Codex adapter discovery and dry-run config materialization.
6. Antigravity adapter discovery and conservative shadow materialization.
7. Process supervisor for non-interactive runs.
8. Logging/redaction.
9. Artifact collector.
10. Tests and documentation updates.

Each milestone should include tests before moving to the next provider or capability.

## 15. Design decisions

| Decision | Rationale |
| --- | --- |
| Use provider-native config instead of abstraction-only config | Avoids drift from official provider behavior. |
| Use adapters as the only provider boundary | Prevents provider-specific logic from leaking into Arbiter Core. |
| Use `state/` for runtime materialization | Keeps repository templates clean and repeatable. |
| Use dry-run manifests | Makes config changes reviewable before execution. |
| Avoid Antigravity global writes by default | Official changelog shows shared GUI/CLI settings under `~/.gemini`; unsafe to mutate blindly. |
| Prefer JSON/JSONL provider modes | Reduces fragile parsing and avoids TUI scraping. |
| Require explicit dangerous-mode opt-in | Aligns with provider security guidance. |

## 16. Open questions for Implementation planning

These must be answered during implementation discovery, not guessed in advance:

1. Which exact Claude Code output flags are available in the installed version for structured streaming?
2. Which Codex JSON events are stable enough for HCOM mapping in the installed version?
3. What is the installed Antigravity executable name and exact headless interface?
4. Can Antigravity artifacts be exported programmatically, or only collected from local state?
5. Which provider config files should be symlinked versus copied into runtime workspaces?
6. What retention policy should apply to transcripts and artifacts?
7. Which external secret manager, if any, should Arbiter support first?

## 17. Acceptance criteria for Design phase

Design phase is complete when:

- `arbiter/DESIGN.md` exists.
- Runtime layout is defined.
- HCOM envelope and message types are defined.
- Adapter contract is defined.
- Provider-specific designs exist for Claude, Codex, and Antigravity.
- Config materialization, secrets, logging, errors, artifacts, and testing are designed.
- No implementation/source code has been generated.
