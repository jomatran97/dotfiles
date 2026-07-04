"""OpenAI Codex adapter."""

from __future__ import annotations

from typing import Optional

from arbiter.materialize import MaterializationManifest, copy_file, copy_tree_contents, ensure_dir
from arbiter.process import CommandPlan
from providers.base import AdapterRunContext, AuthStatus, BaseProviderAdapter, Capability, ProviderError


class CodexAdapter(BaseProviderAdapter):
    provider_name = "codex"
    executable_env_var = "CODEX_BIN"
    executable_names = ("codex",)

    def probe_capabilities(self) -> tuple[Capability, ...]:
        identity = self.identify()
        if not identity.executable:
            return (Capability("cli", False, "executable not found"),)
        help_result = self._run_probe((identity.executable, "--help"))
        exec_help = self._run_probe((identity.executable, "exec", "--help"))
        help_text = ""
        for result in (help_result, exec_help):
            if result:
                help_text += f"{result.stdout}\n{result.stderr}\n"
        has_exec = "exec" in help_text
        has_json = "--json" in help_text
        has_sandbox = "--sandbox" in help_text
        has_approval = "--ask-for-approval" in help_text
        has_mcp = "mcp" in help_text
        return (
            Capability("cli", True, "executable found"),
            Capability("exec", has_exec, "detected from help" if has_exec else "not detected"),
            Capability("json_output", has_json, "detected from help" if has_json else "not detected"),
            Capability("sandbox_flag", has_sandbox, "detected from help" if has_sandbox else "not detected"),
            Capability("approval_flag", has_approval, "detected from help" if has_approval else "not detected"),
            Capability("mcp_cli", has_mcp, "detected from help" if has_mcp else "not detected"),
        )

    def check_auth(self) -> AuthStatus:
        identity = self.identify()
        if not identity.executable:
            return AuthStatus(False, False, "codex executable not found")
        result = self._run_probe((identity.executable, "login", "status"), timeout=15)
        if result is None:
            return AuthStatus(False, True, "failed to run `codex login status`")
        text = (result.stdout or result.stderr).strip()
        return AuthStatus(result.returncode == 0, True, text or f"exit {result.returncode}")

    def build_environment(self, context: AdapterRunContext) -> dict[str, str]:
        home = context.paths.provider_state_dir(self.provider_name) / "home"
        if not context.dry_run:
            home.mkdir(parents=True, exist_ok=True)
        return {"CODEX_HOME": str(home)}

    def materialize_config(self, context: AdapterRunContext) -> MaterializationManifest:
        manifest = MaterializationManifest(self.provider_name, context.workspace.run_id, dry_run=context.dry_run)
        source = context.paths.provider_source_dir(self.provider_name)
        home = context.paths.provider_state_dir(self.provider_name) / "home"
        workspace = context.workspace.workspace
        codex_project_dir = workspace / ".codex"

        ensure_dir(manifest, home)
        ensure_dir(manifest, workspace)
        ensure_dir(manifest, codex_project_dir)

        config_toml = source / "config" / "config.toml"
        if config_toml.exists():
            copy_file(manifest, config_toml, home / "config.toml")
        else:
            manifest.warn(f"no Codex user config template found: {config_toml}")

        project_config = source / "config" / "project.config.toml"
        if project_config.exists():
            copy_file(manifest, project_config, codex_project_dir / "config.toml")

        for profile in sorted((source / "config").glob("*.config.toml")):
            if profile.name != "project.config.toml":
                copy_file(manifest, profile, home / profile.name)

        agents_md = source / "agents" / "AGENTS.md"
        if agents_md.exists():
            copy_file(manifest, agents_md, workspace / "AGENTS.md")

        copy_tree_contents(manifest, source / "prompts", workspace / ".arbiter-codex" / "prompts")
        copy_tree_contents(manifest, source / "agents", workspace / ".arbiter-codex" / "agents")
        copy_tree_contents(manifest, source / "templates", workspace / ".arbiter-codex" / "templates")

        if not context.dry_run:
            manifest.write(context.workspace.manifest_dir / "codex-materialization.json")
        return manifest

    def build_command(
        self,
        context: AdapterRunContext,
        *,
        prompt: str,
        non_interactive: bool = True,
        model: Optional[str] = None,
        sandbox: str = "workspace-write",
        approval: str = "on-request",
        json_output: bool = False,
        profile: Optional[str] = None,
    ) -> CommandPlan:
        identity = self.identify()
        if not identity.executable:
            raise ProviderError("cli_not_found", "Codex executable not found")
        if sandbox == "danger-full-access":
            raise ProviderError("dangerous_mode_requires_explicit_opt_in", "Codex danger-full-access is blocked by default")
        if not non_interactive:
            argv = [identity.executable, "--cd", str(context.workspace.workspace)]
            if model:
                argv.extend(["--model", model])
            if profile:
                argv.extend(["--profile", profile])
            if prompt:
                argv.append(prompt)
        else:
            argv = [identity.executable, "exec"]
            if json_output:
                argv.append("--json")
            argv.extend(["--cd", str(context.workspace.workspace), "--sandbox", sandbox, "--ask-for-approval", approval])
            if model:
                argv.extend(["--model", model])
            if profile:
                argv.extend(["--profile", profile])
            argv.append(prompt)
        return CommandPlan(
            argv=tuple(argv),
            cwd=context.workspace.workspace,
            env=self.build_environment(context),
            provider=self.provider_name,
            run_id=context.workspace.run_id,
            description="Codex non-interactive run" if non_interactive else "Codex interactive run",
        )
