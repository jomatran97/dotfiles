# OpenAI Codex Research

Status: complete for Phase 0 research gate. Sources reviewed were official OpenAI developer documentation and the official OpenAI Codex GitHub repository.

## Official sources reviewed

- https://developers.openai.com/codex/cli/features
- https://developers.openai.com/codex/cli/reference
- https://developers.openai.com/codex/auth
- https://developers.openai.com/codex/config-basic
- https://developers.openai.com/codex/config-advanced
- https://developers.openai.com/codex/config-reference
- https://developers.openai.com/codex/concepts/customization
- https://github.com/openai/codex
- https://raw.githubusercontent.com/openai/codex/main/README.md
- https://raw.githubusercontent.com/openai/codex/main/docs/config.md
- https://raw.githubusercontent.com/openai/codex/main/docs/authentication.md

## Installation

The official Codex CLI README documents these installation paths:

- macOS/Linux bootstrap: `curl -fsSL https://chatgpt.com/codex/install.sh | sh`.
- Windows PowerShell bootstrap: `powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"`.
- npm: `npm install -g @openai/codex`.
- Homebrew: `brew install --cask codex`.
- Direct binaries from the latest GitHub release for macOS, Linux, and Windows architectures.

After installation, run `codex` to start the terminal UI.

## Authentication

Codex supports two OpenAI authentication modes:

- ChatGPT sign-in for subscription/workspace access.
- API-key sign-in for usage-based access.

The CLI and IDE extension support both. Codex Cloud requires ChatGPT sign-in.

Important commands and files:

- `codex login` starts authentication.
- `codex login --device-auth` supports remote/headless login where browser login is not suitable.
- `printenv CODEX_ACCESS_TOKEN | codex login --with-access-token` logs in from a ChatGPT access token.
- `printenv OPENAI_API_KEY | codex login --with-api-key` logs in from an API key.
- `codex login status` exits successfully when credentials are present.
- `codex logout` removes saved credentials.
- Credentials are cached in `~/.codex/auth.json` or an OS credential store. If file-based storage is used, treat `auth.json` like a password.

Relevant environment/configuration controls:

- `CODEX_HOME`: changes the Codex home directory; default is `~/.codex`.
- `CODEX_ACCESS_TOKEN`: useful for token-based automated login.
- `OPENAI_API_KEY`: used for API-key login and API-key workflows.
- `CODEX_CA_CERTIFICATE` or `SSL_CERT_FILE`: custom CA bundle for corporate TLS proxies.
- Managed config can force a login method with `forced_login_method = "chatgpt"` or `"api"` and restrict ChatGPT workspace with `forced_chatgpt_workspace_id`.

## CLI model and workspace behavior

Primary CLI commands include:

- `codex`: interactive full-screen TUI.
- `codex exec`: non-interactive/scripted run that streams output to stdout or JSONL.
- `codex resume`: resume an interactive session by picker, last session, or ID.
- `codex exec resume`: resume non-interactive runs.
- `codex cloud`: browse or launch Codex Cloud tasks from the terminal.
- `codex apply`: apply a Codex Cloud diff locally.
- `codex app` and `codex app-server`: desktop/app-server workflows.
- `codex mcp`: manage MCP servers.
- `codex plugin` and `codex plugin marketplace`: manage plugins.
- `codex features`: persist feature flags in `$CODEX_HOME/config.toml`.
- `codex sandbox`: run commands under Codex sandbox profiles.
- `codex doctor`: diagnostic report for installation, config, auth, runtime, Git, terminal, app-server, and thread inventory.

Workspace behavior:

- Codex runs against the current working directory by default.
- `--cd` / `-C` sets the workspace root without shell `cd`.
- Resume is scoped to the current working directory unless `--all` is used.
- Sessions are stored locally under `~/.codex/sessions/` by default.
- In `workspace-write` sandbox mode, some environments keep `.git/` and `.codex/` protected/read-only even when the rest of the workspace is writable.
- Web search is enabled by default for local tasks in cached mode; `--search` or `web_search = "live"` enables live browsing for a run/config, and `web_search = "disabled"` disables it.

Important flags:

- `--model` / `-m`.
- `--profile` / `-p`.
- `--config` / `-c key=value` for one-off config overrides.
- `--sandbox` / `-s`.
- `--ask-for-approval` / `-a`.
- `--dangerously-bypass-approvals-and-sandbox` / `--yolo`.
- `--strict-config`.
- `--remote` and `--remote-auth-token-env` for remote app-server mode.

## Configuration model

Codex uses TOML configuration.

Configuration locations and precedence, highest first:

1. CLI flags and `--config` overrides.
2. Project `.codex/config.toml` files, from project root down to current working directory; closest wins; trusted projects only.
3. Profile files selected with `--profile`, located at `$CODEX_HOME/<profile>.config.toml`.
4. User config at `$CODEX_HOME/config.toml` (default `~/.codex/config.toml`).
5. System config at `/etc/codex/config.toml` on Unix, if present.

Trust behavior:

- Codex loads project `.codex/` layers only after the project is trusted.
- If untrusted, Codex skips project-local config, hooks, and rules.
- Project config cannot override provider/auth/routing, app request metadata, profile selection, notification, or telemetry keys. Official docs list ignored project-local keys including `openai_base_url`, `chatgpt_base_url`, `model_provider`, `model_providers`, `notify`, `profile`, `profiles`, `experimental_realtime_ws_base_url`, and `otel`.

Common settings:

- `model`: default model.
- `model_provider`: provider id, default `openai`.
- `model_providers.<id>`: custom provider base URL, wire API, auth, headers, retries, and streaming settings.
- `openai_base_url`: base URL override for the built-in OpenAI provider.
- `model_reasoning_effort`, `model_reasoning_summary`, `model_verbosity`, and context/compaction controls.
- `approval_policy`: `untrusted`, `on-request`, `never`, or granular approvals.
- `sandbox_mode`: `read-only`, `workspace-write`, or `danger-full-access` style behavior per docs.
- `sandbox_workspace_write.*`: network access, writable roots, and tmpdir behavior.
- `default_permissions` and `[permissions.<name>]`: built-in or custom permission profiles.
- `[shell_environment_policy]`: controls which environment variables are forwarded to subprocesses.
- `tools.web_search` / `web_search`: web search behavior.
- `mcp_servers.<id>`: MCP server definitions.
- `[hooks]` or `hooks.json`: lifecycle hook configuration.
- `project_doc_max_bytes`: how much Codex reads from `AGENTS.md` files.
- `log_dir`: log directory; explicit setting enables plaintext TUI log in that directory.

## Project guidance and customization

OpenAI documents Codex customization as several complementary layers:

- `AGENTS.md` for persistent project guidance.
- Memories for useful context learned from prior work.
- Skills for reusable workflows and domain expertise.
- MCP for external systems.
- Subagents for specialized delegation.

`AGENTS.md` behavior:

- Global personal guidance can live at `~/.codex/AGENTS.md`.
- Repository guidance can live as `AGENTS.md` in the repo root or nested directories.
- Keep `AGENTS.md` small and update it when recurring assumptions need to persist.

Skills:

- User skills live under `$HOME/.agents/skills`.
- Repo skills live under `.agents/skills`.
- Skills can include scripts, templates, resources, and reference material.
- Skills can be invoked explicitly or selected implicitly when the task matches the description.
- If a skill depends on MCP, declare that dependency in `agents/openai.yaml` according to the official skills documentation.

Subagents:

- Codex supports multi-agent collaboration tools and specialized subagents.
- The config reference notes `features.multi_agent` is stable and on by default, enabling tools such as `spawn_agent`, `send_input`, `resume_agent`, `wait_agent`, and `close_agent`.

## MCP servers

Codex uses Model Context Protocol for external tools and context providers.

- MCP servers are configured in `~/.codex/config.toml` or managed with `codex mcp` commands.
- Codex launches configured servers at session start.
- Server config supports stdio and streamable HTTP patterns with fields such as `command`, `args`, `cwd`, `env`, `env_vars`, `url`, `http_headers`, `env_http_headers`, `bearer_token_env_var`, OAuth resource/scopes, startup timeout, tool timeout, and per-tool approval modes.
- `codex mcp login <name>` starts OAuth for streamable HTTP servers that support OAuth.
- `codex mcp logout <name>` clears MCP OAuth credentials.

## Hooks

Codex can load lifecycle hooks from:

- `$CODEX_HOME/hooks.json`.
- `<repo>/.codex/hooks.json`.
- Inline `[hooks]` tables in active TOML config layers.

Project-local hooks load only when the project `.codex/` layer is trusted. User-level hooks remain independent of project trust. If both `hooks.json` and inline hooks exist in a single layer, Codex loads both and warns; use one representation per layer.

## Environment variables

Key environment variables for Arbiter integration:

- `CODEX_HOME`: isolate Codex config, auth, logs, sessions, profile files, and hooks.
- `OPENAI_API_KEY`: API-key login and API workflows.
- `CODEX_ACCESS_TOKEN`: ChatGPT access-token login.
- `CODEX_CA_CERTIFICATE` and `SSL_CERT_FILE`: TLS root CA bundle.
- Provider-specific variables referenced through `model_providers.<id>.env_key` or `env_http_headers`.
- Remote app-server auth token variables referenced by `--remote-auth-token-env`.

Use `[shell_environment_policy]` to prevent secret leakage to subprocesses while still passing required runtime variables such as `PATH`, language-toolchain variables, or selected API keys.

## Best practices

- Use `$CODEX_HOME` for Arbiter-managed isolation.
- Keep auth files and logs out of version control.
- Prefer project `.codex/config.toml` only for safe project defaults; keep provider/auth in user config or Arbiter-managed isolated config.
- Require trust before enabling project `.codex/` config, hooks, or rules.
- Use `sandbox_mode = "workspace-write"` plus `approval_policy = "on-request"` for local interactive work unless a stricter or fully isolated environment is available.
- Avoid `danger-full-access` / `--yolo` outside containers or disposable worktrees.
- Keep `AGENTS.md` concise and enforce critical rules with tooling, tests, hooks, and permission profiles.

## Limitations and risks

- Codex CLI behavior depends on project trust; untrusted projects intentionally ignore project `.codex/` customization.
- Project config cannot override security-sensitive provider/auth/telemetry fields.
- `auth.json` may be plaintext and must be treated as a secret.
- Web search content is untrusted even in cached mode.
- Full-access sandbox modes can execute destructive commands and should be isolated.
- Official configuration keys evolve; use `codex --strict-config` and `codex doctor` to validate an installed version.

## Arbiter integration strategy

Arbiter should keep the repository `codex/` directory as source-of-truth templates and launch Codex through a provider adapter.

Recommended adapter responsibilities after the research gate:

1. Set `CODEX_HOME` to an Arbiter-controlled runtime directory, such as `state/codex/home`, for isolated sessions.
2. Generate `$CODEX_HOME/config.toml`, profiles, hooks, MCP configuration, and prompt assets from `codex/config`, `codex/prompts`, `codex/agents`, and `codex/templates`.
3. Use `--cd` to select the runtime workspace and `--config` for per-run overrides.
4. Keep OpenAI credentials in environment/credential store, never in this repository.
5. Capture logs under `logs/codex/` and sessions/state under `state/codex/`.
6. Use Codex MCP and multi-agent features only through the adapter's HCOM boundary.
7. Do not mix Codex `.codex/`, `.agents/`, or `$CODEX_HOME` content with Claude or Antigravity configuration.
