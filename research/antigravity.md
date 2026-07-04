# Google Antigravity Research

Status: complete for Phase 0 research gate, with limitations noted. Official sources reviewed were Google Antigravity pages, the official Google Antigravity CLI GitHub repository, official install scripts, and official changelog. The public documentation site is a client-rendered application; direct markdown extraction returned empty content for several docs routes, so the official GitHub README, changelog, install scripts, sitemap, and available official docs URLs were used as the machine-verifiable source set.

## Official sources reviewed

- https://antigravity.google/docs/home
- https://antigravity.google/docs/cli-getting-started
- https://antigravity.google/docs/cli-overview
- https://antigravity.google/product/antigravity-cli
- https://github.com/google-antigravity/antigravity-cli
- https://github.com/google-antigravity/antigravity-cli/blob/main/README.md
- https://github.com/google-antigravity/antigravity-cli/blob/main/CHANGELOG.md
- https://raw.githubusercontent.com/google-antigravity/antigravity-cli/main/README.md
- https://raw.githubusercontent.com/google-antigravity/antigravity-cli/main/CHANGELOG.md
- https://antigravity.google/cli/install.sh
- https://antigravity.google/cli/install.ps1
- https://antigravity.google/cli/install.cmd
- https://antigravity.google/robots.txt
- https://antigravity.google/sitemap.xml

## Documentation availability note

The official Antigravity documentation routes are served by a single-page web app. The fetched HTML contains the app shell and JavaScript bundle, but the documentation body was not available as static markdown/text through the research tool. This document therefore distinguishes:

- Officially documented facts from the README/install scripts/changelog.
- Observed CLI/config behavior from the official changelog.
- Open items that must be verified against the installed CLI or rendered docs before implementation.

No unofficial Antigravity configuration source was used as authoritative.

## Installation

The official README documents these install commands:

- macOS/Linux: `curl -fsSL https://antigravity.google/cli/install.sh | bash`.
- Windows PowerShell: `irm https://antigravity.google/cli/install.ps1 | iex`.
- Windows CMD: `curl -fsSL https://antigravity.google/cli/install.cmd -o install.cmd && install.cmd && del install.cmd`.

The official Unix installer identifies itself as the Antigravity CLI Unix bootstrapper and downloads a flat native build. It supports `-d` / `--dir` for a custom install directory and defaults to `$HOME/.local/bin`. The Windows PowerShell installer defaults to `$env:LOCALAPPDATA\agy\bin`. The official changelog references commands such as `agy changelog`, so Arbiter should discover the installed executable with `agy --help` / `which agy` after installation rather than hardcoding assumptions beyond the official installer output.

## CLI model

The official README describes Antigravity CLI as a terminal-first interface that understands a codebase, makes edits with user permission, and executes commands from the terminal. It brings Antigravity 2.0 capabilities to the terminal, including:

- Multi-step reasoning.
- Multi-file editing.
- Tool calling.
- Persistent history.
- Keyboard-first workflows.
- Remote SSH suitability.
- Minimal resource overhead.

The README compares the CLI with Antigravity 2.0 GUI:

- CLI focus: speed, keyboard efficiency, low overhead, SSH/remote sessions.
- GUI focus: rich visual orchestration and project management.
- Both use the shared core agent engine.

CLI capabilities observed in the official changelog include:

- Slash-command driven TUI commands such as `/help`, `/settings`, `/permissions`, `/resume`, `/logout`, `/hooks`, `/credits`, `/usage`, `/quota`, `/diff`, `/open`, `/add-dir`, `/keybindings`, and `/statusline`.
- Launch flags such as `--model`, `--project`, `--new-project`, `--sandbox`, `-p` / `--print`, and `--conversation` / `-c` are referenced by changelog entries.
- A `models` subcommand is referenced for listing available models.
- `ctrl+c` interrupts active operations on first press and enters the exit flow on double press.
- `ctrl+r` opens the Artifact Review panel.

Implementation should verify exact flag names against the installed CLI version before relying on them.

## Authentication

The official README states:

- The CLI authenticates through the system keyring.
- If no active session exists, it falls back to Google Sign-In.
- Local sessions automatically open the default browser.
- Remote/SSH sessions are detected and print an authorization URL so login can be completed locally.
- `/logout` clears saved credentials.
- Enterprise access requires connecting a GCP project during onboarding.

The changelog also references OAuth token persistence fixes and authentication error handling for signed-out states.

## Configuration and settings

The official README states that Antigravity CLI and Antigravity 2.0 share settings and permissions bidirectionally.

Configuration paths observed in the official changelog:

- Global CLI settings: `~/.gemini/antigravity-cli/settings.json`.
- Project-specific configurations: `~/.gemini/config/projects/`, which take precedence over global settings.
- Shared hooks path: `~/.gemini/config/hooks.json`.
- MCP config migrated to `config/mcp_config.json` under the shared Gemini/Antigravity config area.
- Plugin installation path: `~/.gemini/config/`.
- CLI cache path: `~/.gemini/antigravity-cli/cache`.
- Central workspace-to-project mapping: `~/.gemini/antigravity-cli/cache/projects.json`.

The changelog also notes that unknown fields in `settings.json` are preserved during read/write/merge operations, which matters for forward compatibility.

Because detailed official settings schema was not extractable from the docs site, Arbiter must not invent a schema. It should write only settings verified against the installed CLI or officially rendered docs.

## Workspace and project behavior

Official/observed behavior:

- The CLI is designed for local and remote/SSH workspace use.
- `--project` and `--new-project` launch flags allow explicit project selection or creation.
- `/add-dir` is supported and has shell-style path completion.
- The CLI no longer relies on local `.antigravitycli` workspace directories for project discovery; workspace-to-project mappings are centralized in the CLI cache.
- Invalid/broken symlinks in `.antigravitycli/` are skipped instead of failing project discovery.
- The CLI displays workspace information in the header and `/help` menu, and prior changelog entries fixed multi-workspace display issues.

## Multi-agent support

Official README language says Antigravity CLI and Antigravity 2.0 share the core agent engine. The changelog references:

- Subagent conversations, which are skipped from `/resume` so the picker stays focused on direct user-initiated conversations.
- A default interaction timeout being restricted specifically to subagents.
- Plugin discovery for skills and agents.
- Customizations and specialized agents available through plugin directories.

The public official docs site likely contains more details on Antigravity agents and harness behavior, but this was not available as static text during research. Arbiter should verify multi-agent APIs in the installed CLI/docs before implementing an adapter.

## Artifacts

The official changelog confirms artifact support in the CLI:

- Artifact viewer and artifact detail view.
- Artifact Review panel opened with `ctrl+r`.
- Artifact status in the status line.
- Artifact viewer gutter numbering and source-line mapping.
- Handling of large step histories in artifact view.
- Inline comments in artifact detail view.

The README also documents session export from the terminal CLI to the Antigravity 2.0 GUI for continued work.

## Permissions and sandboxing

The official README says Antigravity CLI makes edits with user permission. The official changelog adds details:

- `/permissions` can add, edit, and remove permission rules from multiple config scopes.
- CLI permissions merge project-level permissions, user settings shared with Antigravity, and CLI `settings.json`.
- Project-specific configs in `~/.gemini/config/projects/` take precedence over global settings.
- Command permission security was improved so `Always Approve` rule matching is strict/non-regex by default; users can opt into regex matching with a `regex:` prefix.
- Permission matching for quoted arguments, shell redirections, PowerShell scripts, and unparseable strings has been hardened.
- `.git` is treated as a dangerous path in sandbox execution.
- A `proceed-in-sandbox` tool permission mode auto-approves terminal commands that run inside the secure sandbox and asks when a command attempts to bypass it.
- `ask` permissions are preserved during settings updates.

Security warning from README: AI coding agents carry risks including autonomous code execution, data exfiltration, prompt injection, and supply-chain risk. Users must monitor and verify agent actions.

## Environment variables

Environment variables explicitly referenced by official changelog/install material:

- `AGY_CLI_CMD_OUTPUT_PERCENTAGE`: customize maximum command-output height in the TUI as a percentage of terminal height.
- `AGY_CLI_DISABLE_LATEX`: disable LaTeX rendering globally.
- `AGY_CLI_HIDE_ACCOUNT_INFO`: hide email and plan tier from the header.
- `$EDITOR`: used by editor-launch behavior and fixed for arguments containing `=`.
- Installer variables/paths include `$HOME`, `$LOCALAPPDATA`, and custom install directory flags.

No complete official environment variable reference was extractable from the docs site. Treat this list as confirmed but not exhaustive.

## Best practices

- Use the official installer and verify the actual binary path/version before adapter implementation.
- Do not commit Google sign-in credentials, system keyring exports, cache files, conversations, or project mappings.
- Keep Arbiter's `antigravity/` directory as a source-of-truth layer; sync to official Antigravity/Gemini config paths only through the adapter.
- Treat official shared settings paths as user-global and avoid modifying them without explicit user approval.
- Use project-specific config where officially supported rather than global settings when isolating Arbiter projects.
- Preserve unknown settings fields to avoid downgrading or corrupting newer Antigravity config.
- Verify all permission changes through the CLI UI or official settings schema before writing them.
- Monitor all agent actions and prefer sandboxed/permission-gated execution.

## Limitations and open verification items

- The official docs site was accessible but not machine-extractable as static documentation in this research environment.
- Detailed settings schema, exact CLI reference, and Antigravity Harness APIs need verification through rendered docs or installed CLI help before implementation.
- The CLI appears to use `agy` based on official changelog references, but the adapter should discover the executable after installation.
- Config paths are based on official changelog entries and may vary by version/platform.
- Shared settings synchronize with Antigravity 2.0, so changes may affect GUI behavior.
- Data-use opt-out exists via settings per README, but the exact setting key must be verified before automation.

## Arbiter integration strategy

Arbiter should treat `antigravity/` in this repository as an isolated source-of-truth workspace for Antigravity-specific prompts, settings templates, agent assets, and artifact storage. It should not mix these with Claude or Codex configuration.

Recommended adapter responsibilities after the research gate:

1. Discover the Antigravity CLI executable and version after installation.
2. Keep runtime state under `state/antigravity/` and logs under `logs/antigravity/`.
3. Stage prompt and agent assets from `antigravity/prompts` and `antigravity/agents` into the official config/project mechanism only after schema verification.
4. Use `--project`, `--new-project`, `/add-dir`, and sandbox/permission flags only after confirming exact installed CLI support.
5. Treat `~/.gemini/...` paths as external global state; never write to them directly without an adapter-managed backup/merge strategy.
6. Store exported/reviewed artifacts under `antigravity/artifacts/` or `state/antigravity/artifacts/`, depending on whether they are source assets or runtime outputs.
7. Keep HCOM communication behind the Antigravity provider adapter.
8. Require explicit user approval before changing shared settings or permission rules that affect the Antigravity GUI.
