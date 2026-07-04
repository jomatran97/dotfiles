"""Google Antigravity adapter.

The adapter is deliberately conservative because the official Antigravity docs site
was only partially machine-readable during Phase 0 research.
"""

from __future__ import annotations

from typing import Optional

from arbiter.materialize import MaterializationManifest, copy_tree_contents, ensure_dir
from arbiter.process import CommandPlan
from providers.base import AdapterRunContext, AuthStatus, BaseProviderAdapter, Capability, ProviderError


class AntigravityAdapter(BaseProviderAdapter):
    provider_name = "antigravity"
    executable_env_var = "AGY_BIN"
    executable_names = ("agy", "antigravity", "antigravity-cli")

    def _help_text(self) -> str:
        identity = self.identify()
        if not identity.executable:
            return ""
        result = self._run_probe((identity.executable, "--help"))
        if not result:
            return ""
        return f"{result.stdout}\n{result.stderr}"

    def probe_capabilities(self) -> tuple[Capability, ...]:
        identity = self.identify()
        if not identity.executable:
            return (Capability("cli", False, "executable not found"),)
        help_text = self._help_text()
        return (
            Capability("cli", True, "executable found"),
            Capability("help", bool(help_text), "detected help output" if help_text else "help output unavailable"),
            Capability("print_mode", "--print" in help_text or " -p" in help_text, "detected from help" if ("--print" in help_text or " -p" in help_text) else "not detected"),
            Capability("project_flags", "--project" in help_text or "--new-project" in help_text, "detected from help" if ("--project" in help_text or "--new-project" in help_text) else "not detected"),
            Capability("sandbox_flag", "--sandbox" in help_text, "detected from help" if "--sandbox" in help_text else "not detected"),
        )

    def check_auth(self) -> AuthStatus:
        # Official README says the CLI uses system keyring and falls back to Google Sign-In.
        # No stable non-invasive auth-status command was found during Phase 0, so auth is
        # considered launch-time/provider-managed rather than blocking dry-run readiness.
        return AuthStatus(True, False, "Antigravity auth is provider-managed; no stable auth-status probe configured")

    def build_environment(self, context: AdapterRunContext) -> dict[str, str]:
        # Keep environment minimal; do not redirect shared ~/.gemini config unless an
        # official variable is verified in a future implementation milestone.
        return {}

    def materialize_config(self, context: AdapterRunContext) -> MaterializationManifest:
        manifest = MaterializationManifest(self.provider_name, context.workspace.run_id, dry_run=context.dry_run)
        source = context.paths.provider_source_dir(self.provider_name)
        shadow = context.paths.provider_state_dir(self.provider_name) / "shadow-config" / context.workspace.run_id
        workspace = context.workspace.workspace

        ensure_dir(manifest, workspace)
        ensure_dir(manifest, shadow)
        copy_tree_contents(manifest, source / "settings", shadow / "settings")
        copy_tree_contents(manifest, source / "agents", shadow / "agents")
        copy_tree_contents(manifest, source / "prompts", shadow / "prompts")
        copy_tree_contents(manifest, source / "artifacts", context.workspace.artifacts / "source-artifacts")
        manifest.warn("Antigravity config staged as shadow config only; shared ~/.gemini config is not mutated")

        if not context.dry_run:
            manifest.write(context.workspace.manifest_dir / "antigravity-materialization.json")
        return manifest

    def build_command(
        self,
        context: AdapterRunContext,
        *,
        prompt: str,
        non_interactive: bool = True,
        model: Optional[str] = None,
        project: Optional[str] = None,
        sandbox: Optional[str] = None,
    ) -> CommandPlan:
        identity = self.identify()
        if not identity.executable:
            raise ProviderError("cli_not_found", "Antigravity executable not found")
        help_text = self._help_text()
        argv = [identity.executable]
        if project and "--project" in help_text:
            argv.extend(["--project", project])
        if sandbox and "--sandbox" in help_text:
            argv.extend(["--sandbox", sandbox])
        if non_interactive:
            if "--print" in help_text:
                argv.extend(["--print", prompt])
            elif " -p" in help_text or "-p," in help_text:
                argv.extend(["-p", prompt])
            else:
                raise ProviderError(
                    "capability_missing",
                    "Antigravity non-interactive print mode was not detected; run `doctor antigravity` and verify installed CLI help",
                )
        elif prompt:
            argv.append(prompt)
        return CommandPlan(
            argv=tuple(argv),
            cwd=context.workspace.workspace,
            env=self.build_environment(context),
            provider=self.provider_name,
            run_id=context.workspace.run_id,
            description="Antigravity non-interactive run" if non_interactive else "Antigravity interactive run",
        )
