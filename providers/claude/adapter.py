"""Claude Code adapter."""

from __future__ import annotations

from typing import Optional

from arbiter.materialize import MaterializationManifest, copy_file, copy_tree_contents, ensure_dir
from arbiter.process import CommandPlan
from providers.base import AdapterRunContext, AuthStatus, BaseProviderAdapter, Capability, ProviderError


class ClaudeAdapter(BaseProviderAdapter):
    provider_name = "claude"
    executable_env_var = "CLAUDE_BIN"
    executable_names = ("claude",)

    def probe_capabilities(self) -> tuple[Capability, ...]:
        identity = self.identify()
        if not identity.executable:
            return (Capability("cli", False, "executable not found"),)
        help_result = self._run_probe((identity.executable, "--help"))
        help_text = ""
        if help_result:
            help_text = f"{help_result.stdout}\n{help_result.stderr}"
        has_print = "--print" in help_text or "\n-p" in help_text or " -p" in help_text
        has_auth = "auth" in help_text
        has_permission_mode = "--permission-mode" in help_text
        has_mcp = "mcp" in help_text
        return (
            Capability("cli", True, "executable found"),
            Capability("print_mode", has_print, "detected from help" if has_print else "not detected"),
            Capability("auth_status", has_auth, "detected from help" if has_auth else "not detected"),
            Capability("permission_mode_flag", has_permission_mode, "detected from help" if has_permission_mode else "not detected"),
            Capability("mcp_cli", has_mcp, "detected from help" if has_mcp else "not detected"),
        )

    def check_auth(self) -> AuthStatus:
        identity = self.identify()
        if not identity.executable:
            return AuthStatus(False, False, "claude executable not found")
        result = self._run_probe((identity.executable, "auth", "status"), timeout=15)
        if result is None:
            return AuthStatus(False, True, "failed to run `claude auth status`")
        text = (result.stdout or result.stderr).strip()
        return AuthStatus(result.returncode == 0, True, text or f"exit {result.returncode}")

    def build_environment(self, context: AdapterRunContext) -> dict[str, str]:
        config_dir = context.paths.provider_state_dir(self.provider_name) / "config"
        if not context.dry_run:
            config_dir.mkdir(parents=True, exist_ok=True)
        return {"CLAUDE_CONFIG_DIR": str(config_dir)}

    def materialize_config(self, context: AdapterRunContext) -> MaterializationManifest:
        manifest = MaterializationManifest(self.provider_name, context.workspace.run_id, dry_run=context.dry_run)
        source = context.paths.provider_source_dir(self.provider_name)
        workspace = context.workspace.workspace
        claude_dir = workspace / ".claude"

        ensure_dir(manifest, workspace)
        ensure_dir(manifest, claude_dir)

        claude_md = source / "CLAUDE.md"
        if claude_md.exists():
            copy_file(manifest, claude_md, workspace / "CLAUDE.md")
        else:
            manifest.warn(f"missing Claude source CLAUDE.md: {claude_md}")

        settings_json = source / "settings" / "settings.json"
        if settings_json.exists():
            copy_file(manifest, settings_json, claude_dir / "settings.json")
        else:
            copy_tree_contents(manifest, source / "settings", claude_dir / "settings")

        copy_tree_contents(manifest, source / "agents", claude_dir / "agents")
        copy_tree_contents(manifest, source / "skills", claude_dir / "skills")
        copy_tree_contents(manifest, source / "hooks", claude_dir / "hooks")

        mcp_json_candidates = [source / "mcp" / ".mcp.json", source / "mcp" / "mcp.json"]
        copied_mcp = False
        for candidate in mcp_json_candidates:
            if candidate.exists():
                copy_file(manifest, candidate, workspace / ".mcp.json")
                copied_mcp = True
                break
        if not copied_mcp:
            copy_tree_contents(manifest, source / "mcp", claude_dir / "mcp")

        if not context.dry_run:
            manifest.write(context.workspace.manifest_dir / "claude-materialization.json")
        return manifest

    def build_command(
        self,
        context: AdapterRunContext,
        *,
        prompt: str,
        non_interactive: bool = True,
        model: Optional[str] = None,
        permission_mode: str = "default",
        extra_args: Optional[list[str]] = None,
    ) -> CommandPlan:
        identity = self.identify()
        if not identity.executable:
            raise ProviderError("cli_not_found", "Claude Code executable not found")
        if not non_interactive:
            argv: list[str] = [identity.executable]
            if prompt:
                argv.append(prompt)
        else:
            argv = [identity.executable]
            if permission_mode:
                if permission_mode == "bypassPermissions":
                    raise ProviderError("dangerous_mode_requires_explicit_opt_in", "Claude bypassPermissions is blocked by default")
                argv.extend(["--permission-mode", permission_mode])
            if model:
                argv.extend(["--model", model])
            if extra_args:
                argv.extend(extra_args)
            argv.extend(["-p", prompt])
        return CommandPlan(
            argv=tuple(argv),
            cwd=context.workspace.workspace,
            env=self.build_environment(context),
            provider=self.provider_name,
            run_id=context.workspace.run_id,
            description="Claude Code non-interactive run" if non_interactive else "Claude Code interactive run",
        )
