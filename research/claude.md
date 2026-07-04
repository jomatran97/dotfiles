# Claude Code Research

Status: complete for Phase 0 research gate. Sources reviewed were official Anthropic Claude Code documentation unless otherwise noted.

## Official sources reviewed

- https://docs.anthropic.com/en/docs/claude-code/overview
- https://code.claude.com/docs/en/setup
- https://code.claude.com/docs/en/quickstart
- https://code.claude.com/docs/en/cli-reference
- https://code.claude.com/docs/en/claude-directory
- https://code.claude.com/docs/en/memory
- https://code.claude.com/docs/en/settings
- https://code.claude.com/docs/en/env-vars
- https://code.claude.com/docs/en/sub-agents
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/mcp
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/permissions

## Installation

Claude Code supports macOS, Linux, WSL, and native Windows. The official setup page documents a native installer as the recommended path, plus Homebrew, WinGet, Linux package managers, and npm.

Important installation notes:

- Native installs auto-update in the background by default.
- Homebrew installs use casks (`claude-code` stable and `claude-code@latest`) and require `brew upgrade` for updates unless configured otherwise.
- WinGet installs require `winget upgrade Anthropic.ClaudeCode` for updates.
- Linux package repositories are signed and available for apt, dnf, and apk.
- npm install is supported with `npm install -g @anthropic-ai/claude-code`; npm requires Node.js 18+ and installs the same native binary through platform-specific optional dependencies.
- Do not use `sudo npm install -g` per Anthropic guidance.
- On native Windows, Git for Windows is recommended so Claude Code can use Git Bash; otherwise Claude Code uses PowerShell tooling.

## CLI model

The `claude` command starts the interactive terminal UI. Officially documented CLI patterns include:

- `claude` for an interactive session.
- `claude "query"` for an initial prompt.
- `claude -p "query"` for non-interactive print/SDK-style use.
- `cat file | claude -p "query"` for piped input.
- `claude -c` / `--continue` and `claude -r` / `--resume` for previous conversations.
- `claude update`, `claude install [version]`, and `claude doctor` for maintenance and diagnostics.
- `claude auth login`, `claude auth logout`, and `claude auth status` for authentication.
- `claude agents` and related background-agent commands for parallel/background sessions.
- `claude mcp ...` for MCP server management and OAuth login/logout.
- `claude project purge` for deleting project-scoped local state.

Important flags include `--model`, `--effort`, `--permission-mode`, `--allowedTools`, `--disallowedTools`, `--add-dir`, `--agent`, `--agents`, `--settings`, `--mcp-config`, `--debug`, `--safe-mode`, and `--dangerously-skip-permissions` / `--allow-dangerously-skip-permissions`.

## Authentication

Claude Code supports Claude.ai subscription authentication and Anthropic Console/API-key-style authentication. Official environment-variable behavior is important:

- `ANTHROPIC_API_KEY` sends an API key as `X-Api-Key`. When set, it is used instead of a Claude subscription; in non-interactive mode it is always used when present.
- `apiKeyHelper` in settings can dynamically generate auth values.
- OAuth automation variables include `CLAUDE_CODE_OAUTH_TOKEN`, `CLAUDE_CODE_OAUTH_REFRESH_TOKEN`, and `CLAUDE_CODE_OAUTH_SCOPES`.
- Managed settings can restrict login method and organization membership.

## Configuration model

`settings.json` is the official configuration mechanism. Claude Code has hierarchical scopes:

- Managed settings: central organization policy delivered by server-managed settings, macOS plist, Windows registry, or system `managed-settings.json` / `managed-mcp.json`.
- User settings: `~/.claude/settings.json`.
- Shared project settings: `.claude/settings.json`.
- Local project settings: `.claude/settings.local.json` for private per-project settings; add to `.gitignore` if created manually.
- CLI flags and explicit `--settings` overrides affect a session.

Claude Code watches settings files and reloads many keys while running, including permissions, hooks, and credential helpers. Some keys, such as `model`, apply only at session start or via in-session commands. The official JSON schema is `https://json.schemastore.org/claude-code-settings.json`.

Common settings categories:

- `permissions`: allow/ask/deny rules, `additionalDirectories`, default permission mode, sandbox settings.
- `hooks`: lifecycle automation.
- `env`: environment variables Claude Code reads at startup.
- `model`, `fallbackModel`, `effortLevel`, model allowlists, and reasoning controls.
- `apiKeyHelper`, telemetry/OTel helpers, status line configuration, skill visibility, and UI settings.

## Project structure and `.claude/`

Official `.claude` behavior:

- Project-scope files live under the repository `.claude/` directory, with exceptions for root `CLAUDE.md`, `.mcp.json`, and `.worktreeinclude`.
- Global-scope files live under `~/.claude/`.
- If `CLAUDE_CONFIG_DIR` is set, paths that would normally be under `~/.claude` are rooted there instead.
- `~/.claude` also stores plaintext application data: transcripts, prompt history, file snapshots, caches, logs, and project state.

Important authorable paths:

- `CLAUDE.md` or `.claude/CLAUDE.md`: project instructions.
- `.claude/settings.json`: shared project settings.
- `.claude/settings.local.json`: private local settings.
- `.claude/agents/*.md`: subagents.
- `.claude/skills/<name>/SKILL.md`: skills.
- `.claude/hooks/`: hook scripts referenced by settings.
- `.mcp.json`: project-scoped MCP servers.
- `.claude/rules/*.md`: modular/path-scoped rules.

## `CLAUDE.md`

Claude Code reads `CLAUDE.md`, not `AGENTS.md`. If a repository already uses `AGENTS.md`, Anthropic recommends creating `CLAUDE.md` that imports it with `@AGENTS.md` or symlinking where appropriate.

Key behavior:

- `CLAUDE.md` files are markdown instructions loaded into context at session start.
- They are context, not enforced policy; use permissions or hooks for enforcement.
- Project files can live at `./CLAUDE.md` or `./.claude/CLAUDE.md`.
- Personal project instructions can use `CLAUDE.local.md` and should be gitignored.
- Files load from broader to more specific scope; local instructions are appended after shared ones.
- Imports use `@path` syntax, support relative and absolute paths, and recurse up to four hops.
- Anthropic recommends concise, structured files, targeting under about 200 lines per `CLAUDE.md`.

## Subagents

Subagents are specialized assistants with their own context window, system prompt, tool access, and permissions. Built-ins include agents such as Explore, Plan, and general-purpose.

Custom subagents:

- Are markdown files with YAML frontmatter plus a markdown body prompt.
- Project subagents live in `.claude/agents/`; user subagents live in `~/.claude/agents/`.
- Required frontmatter fields are `name` and `description`.
- Supported fields include `tools`, `disallowedTools`, `model`, `permissionMode`, `skills`, `mcpServers`, `hooks`, `maxTurns`, `memory`, `effort`, `background`, `isolation`, `color`, and `initialPrompt`.
- Subagents can be created through `/agents`, defined on disk, passed via `--agents`, or distributed by plugins.
- Plugin subagents intentionally ignore `hooks`, `mcpServers`, and `permissionMode` for security.
- Specific subagents can be denied with permission rules such as `Agent(name)`.

## Skills

Skills extend Claude with reusable workflows and reference material. A skill is a directory containing `SKILL.md`.

Official behavior:

- Skills can live in `~/.claude/skills/<name>/SKILL.md` or `.claude/skills/<name>/SKILL.md`.
- Skill metadata is loaded so Claude can discover the skill; full content loads only when invoked, unless preloaded into a subagent.
- Custom commands and skills are unified. Legacy `.claude/commands/*.md` still work, but skills are recommended.
- Frontmatter fields include `name`, `description`, `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `disallowed-tools`, `hooks`, `context`, and related execution controls.
- Supporting files such as templates, references, and scripts may live alongside `SKILL.md` and should be referenced from the skill.
- Project skills can grant allowed tools after workspace trust is accepted; review them before trusting a repository.
- `disableSkillShellExecution` can disable inline shell execution in user/project/plugin skills.

## MCP servers

Claude Code uses Model Context Protocol to connect to external tools and data sources.

Configuration and operations:

- `claude mcp add --transport http <name> <url>` adds an HTTP MCP server; HTTP is the recommended remote transport.
- SSE is documented but deprecated in favor of HTTP where available.
- Stdio servers run local processes and must place server arguments after `--`.
- WebSocket servers are configured via `.mcp.json` or `claude mcp add-json`.
- MCP scopes are local, project, and user. Project scope writes `.mcp.json`; user and local scope are stored under `~/.claude.json`.
- Project-scoped `.mcp.json` servers require user approval before use.
- Environment variables can be expanded in `.mcp.json` with `${VAR}` or default forms.
- Remote HTTP/SSE servers can authenticate through OAuth; `claude mcp login <name>` supports OAuth from the shell.
- Claude.ai connectors can be available when authenticated with a Claude.ai account; `disableClaudeAiConnectors` can disable them.

## Hooks

Hooks are configured in JSON settings and run at lifecycle events. Handler types include command, HTTP, MCP tool, prompt, and agent hooks.

Important events include `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Notification`, `SubagentStop`, `Stop`, `StopFailure`, `ConfigChange`, `FileChanged`, and `SessionEnd`.

Operational details:

- Command hooks receive JSON on stdin.
- HTTP hooks receive the same JSON as a POST body.
- Hooks can be filtered with `matcher` and `if` patterns.
- Exit code `2` is the blocking code for most enforcement hooks; exit code `1` is usually non-blocking.
- `PreToolUse` hooks can deny calls but do not bypass deny/ask permission rules.
- `/hooks` is a read-only browser for configured hooks.
- `disableAllHooks` disables hooks at the applicable settings level, except managed hooks cannot be disabled by lower scopes.

## Permissions

Claude Code permissions are enforced by the client, not by the model.

Core concepts:

- Rules are `allow`, `ask`, and `deny`.
- Evaluation order is deny, then ask, then allow; specificity does not override deny-first semantics.
- Permission modes include `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, and `bypassPermissions`.
- `bypassPermissions` skips most permission prompts and should be used only in isolated environments such as containers or VMs.
- Tool rules use forms like `Bash(npm run *)`, `Read(./.env)`, `Edit(/src/**/*.ts)`, `WebFetch(domain:example.com)`, `mcp__server__tool`, and `Agent(name)`.
- Additional directories grant file access but are not full configuration roots; most `.claude/` config is not discovered from them.
- Sandboxing provides OS-level enforcement for Bash commands and complements permission rules.

## Environment variables

Important variables for Arbiter integration:

- `CLAUDE_CONFIG_DIR`: relocates user-level Claude Code config/data from `~/.claude`.
- `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL`, and model override variables.
- `BASH_DEFAULT_TIMEOUT_MS`, `BASH_MAX_TIMEOUT_MS`, `BASH_MAX_OUTPUT_LENGTH`.
- `MCP_TIMEOUT`, `MCP_TOOL_TIMEOUT`, `MAX_MCP_OUTPUT_TOKENS`, `CLAUDE_CODE_MCP_TOOL_IDLE_TIMEOUT`, `CLAUDE_CODE_MCP_ALLOWLIST_ENV`.
- `CLAUDE_CODE_DISABLE_*` variables for auto memory, bundled skills, hooks-related behavior, updates, telemetry, git instructions, file checkpointing, and nonessential traffic.
- `CLAUDE_CODE_SAFE_MODE` for troubleshooting broken customization.
- `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, and certificate/TLS-related variables for enterprise routing.

Environment variables can be set in the shell or in `settings.json` under `env`. Where both an env var and settings key exist, the env var generally takes precedence.

## Best practices

- Keep provider configuration isolated; do not commit personal `settings.local.json`, auth state, transcripts, or secrets.
- Use project `.claude/settings.json` only for team-safe defaults.
- Use permissions and hooks for enforcement; use `CLAUDE.md` for guidance.
- Keep `CLAUDE.md` concise and move repeatable procedures to skills.
- Prefer project skills/subagents only after trust review.
- Use `CLAUDE_CONFIG_DIR` when Arbiter must isolate Claude Code user/global state.
- Prefer explicit MCP scopes and avoid placing secrets in project `.mcp.json`.

## Limitations and risks

- Official behavior changes quickly; validate against the installed `claude --version` and `claude --help` before relying on newer fields.
- `CLAUDE.md` is not a security boundary.
- Bash permission patterns are useful but not equivalent to OS-level sandboxing.
- Transcripts and history under Claude Code application data are plaintext and may contain tool outputs or secrets.
- Project config and MCP servers can be powerful; require trust review before enabling.

## Arbiter integration strategy

Arbiter should treat `claude/` in this repository as the source-of-truth template workspace for Claude Code integration assets, then materialize or map them to the official `.claude/`, `.mcp.json`, and `CLAUDE_CONFIG_DIR` locations for a launched provider session.

Recommended adapter responsibilities after the research gate:

1. Start `claude` only through a Claude provider adapter.
2. Set `CLAUDE_CONFIG_DIR` to an Arbiter-controlled state path when isolation is required.
3. Copy or synthesize `.claude/settings.json`, `.claude/agents/`, `.claude/skills/`, hooks, and MCP config from `claude/` into the runtime project workspace.
4. Pass `--settings`, `--mcp-config`, `--permission-mode`, `--model`, and `--add-dir` explicitly when session-specific behavior is needed.
5. Keep auth tokens out of this repository; read them from the user environment, keychain, or external secret manager.
6. Capture logs under `logs/claude/` and provider state under `state/claude/`.
7. Expose HCOM only through the adapter, never by mixing Claude internal config with Codex or Antigravity config.
