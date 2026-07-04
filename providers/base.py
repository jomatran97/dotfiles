"""Base provider adapter contract."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import os
import shutil
import subprocess
from typing import Any, Iterable, Optional, Tuple, Union
from uuid import uuid4

from arbiter.audit import AuditLogger
from arbiter.hcom import HCOMEnvelope, HCOMType, TaskEnvelope, assert_task_envelope, envelope
from arbiter.lifecycle import LifecycleState
from arbiter.materialize import MaterializationManifest
from arbiter.paths import ArbiterPaths
from arbiter.process import CommandPlan, ProcessResult, ProcessSupervisor
from arbiter.session_store import SessionRecord, SessionStore
from arbiter.workspace import RunWorkspace, WorkspaceManager


class ProviderError(RuntimeError):
    """Provider adapter error with a machine-readable code."""

    def __init__(self, code: str, message: str, *, detail: Optional[dict[str, Any]] = None) -> None:
        super().__init__(message)
        self.code = code
        self.detail = detail or {}


@dataclass(frozen=True)
class ProviderIdentity:
    provider: str
    executable: Optional[str]
    version: Optional[str]
    found: bool
    detail: Optional[str] = None


@dataclass(frozen=True)
class Capability:
    name: str
    supported: bool
    detail: Optional[str] = None


@dataclass(frozen=True)
class AuthStatus:
    ready: bool
    checked: bool
    message: str


@dataclass(frozen=True)
class Readiness:
    provider: str
    ready: bool
    identity: ProviderIdentity
    auth: AuthStatus
    capabilities: Tuple[Capability, ...]
    errors: Tuple[str, ...] = ()
    warnings: Tuple[str, ...] = ()


@dataclass
class AdapterRunContext:
    paths: ArbiterPaths
    workspace: RunWorkspace
    dry_run: bool
    audit: Optional[AuditLogger] = None
    metadata: dict[str, Any] = field(default_factory=dict)


class BaseProviderAdapter:
    """Base adapter with shared discovery, logging, and HCOM helpers."""

    provider_name = "base"
    executable_env_var = None  # type: Optional[str]
    executable_names = ()  # type: Tuple[str, ...]

    def __init__(self, paths: ArbiterPaths) -> None:
        self.paths = paths
        self.supervisor = ProcessSupervisor()
        self.sessions = SessionStore(paths)

    def find_executable(self) -> Optional[str]:
        if self.executable_env_var:
            override = os.environ.get(self.executable_env_var)
            if override:
                return override if Path(override).exists() or shutil.which(override) else None
        for name in self.executable_names:
            resolved = shutil.which(name)
            if resolved:
                return resolved
        return None

    def _run_probe(self, argv: Iterable[str], *, timeout: int = 10) -> Optional[subprocess.CompletedProcess]:
        try:
            return subprocess.run(
                list(argv),
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
        except (OSError, subprocess.SubprocessError):
            return None

    def _version_from(self, executable: str, candidates: Tuple[Tuple[str, ...], ...]) -> Tuple[Optional[str], Optional[str]]:
        for args in candidates:
            completed = self._run_probe((executable, *args))
            if completed is None:
                continue
            text = (completed.stdout or completed.stderr).strip()
            if completed.returncode == 0 and text:
                return text.splitlines()[0], None
        return None, "version command failed or produced no output"

    def identify(self) -> ProviderIdentity:
        executable = self.find_executable()
        if not executable:
            names = ", ".join(self.executable_names) or self.provider_name
            return ProviderIdentity(self.provider_name, None, None, False, "no executable found (%s)" % names)
        version, detail = self._version_from(executable, (("--version",), ("version",), ("-v",)))
        return ProviderIdentity(self.provider_name, executable, version, True, detail)

    def probe_capabilities(self) -> Tuple[Capability, ...]:
        identity = self.identify()
        if not identity.executable:
            return (Capability("cli", False, "executable not found"),)
        help_result = self._run_probe((identity.executable, "--help"))
        help_text = ""
        if help_result:
            help_text = "%s\n%s" % (help_result.stdout, help_result.stderr)
        return (Capability("cli", True, "executable found"), Capability("help", bool(help_text), None))

    def check_auth(self) -> AuthStatus:
        return AuthStatus(True, False, "auth check not implemented for this adapter")

    def check_readiness(self) -> Readiness:
        identity = self.identify()
        capabilities = self.probe_capabilities()
        auth = self.check_auth() if identity.found else AuthStatus(False, False, "auth not checked because executable is missing")
        errors = []  # type: list[str]
        warnings = []  # type: list[str]
        if not identity.found:
            errors.append("cli_not_found")
        if auth.checked and not auth.ready:
            errors.append("auth_required")
        if not auth.checked:
            warnings.append(auth.message)
        return Readiness(
            provider=self.provider_name,
            ready=not errors,
            identity=identity,
            auth=auth,
            capabilities=capabilities,
            errors=tuple(errors),
            warnings=tuple(warnings),
        )

    def prepare_context(self, *, run_id: Optional[str] = None, dry_run: bool = False) -> AdapterRunContext:
        workspace = WorkspaceManager(self.paths).prepare(self.provider_name, run_id=run_id, create=not dry_run)
        audit = None if dry_run else AuditLogger(workspace.logs)
        return AdapterRunContext(self.paths, workspace, dry_run, audit)

    def build_environment(self, context: AdapterRunContext) -> dict[str, str]:
        return {}

    def materialize_config(self, context: AdapterRunContext) -> MaterializationManifest:
        return MaterializationManifest(self.provider_name, context.workspace.run_id, dry_run=context.dry_run)

    def build_command(
        self,
        context: AdapterRunContext,
        *,
        prompt: str,
        non_interactive: bool = True,
        **kwargs: Any
    ) -> CommandPlan:
        raise NotImplementedError

    def run_non_interactive(
        self,
        context: AdapterRunContext,
        *,
        prompt: str,
        timeout_seconds: Optional[Union[int, float]] = None,
        **kwargs: Any
    ) -> ProcessResult:
        plan = self.build_command(context, prompt=prompt, non_interactive=True, **kwargs)
        return self.supervisor.run(plan, timeout_seconds=timeout_seconds)

    def send_hcom(
        self,
        context: AdapterRunContext,
        message: HCOMEnvelope,
        *,
        detached: bool = False,
        timeout_seconds: Optional[Union[int, float]] = None,
        **kwargs: Any,
    ) -> HCOMEnvelope:
        self.supervisor.reap_children()
        self.sessions.reconcile()
        if message.type != HCOMType.TASK_SUBMIT.value:
            raise ProviderError("unsupported_hcom_type", f"unsupported HCOM message type {message.type!r}")
        task = TaskEnvelope.from_dict(message.payload.get("task") or {})
        assert_task_envelope(self.paths, task)
        if task.provider != self.provider_name:
            raise ProviderError("provider_mismatch", f"task provider {task.provider!r} does not match adapter {self.provider_name!r}")
        session_id = message.session_id or f"{self.provider_name}-{uuid4().hex[:12]}"
        plan = self.build_command(context, prompt=task.prompt, non_interactive=True, model=task.model, **kwargs)
        if context.audit:
            context.audit.write("events", envelope(
                message_type=HCOMType.SESSION_START,
                source="arbiter",
                target=self.provider_name,
                payload={"task": task.to_dict(), "command": plan.redacted()},
                run_id=context.workspace.run_id,
                session_id=session_id,
                correlation_id=message.message_id,
            ).to_dict())
        if detached:
            stdout_path = context.workspace.logs / "stdout.log"
            stderr_path = context.workspace.logs / "stderr.log"
            handle = self.supervisor.start(plan, stdout_path=stdout_path, stderr_path=stderr_path)
            self.sessions.put(SessionRecord(
                session_id=session_id,
                run_id=context.workspace.run_id,
                provider=self.provider_name,
                agent=task.agent,
                model=task.model,
                pid=handle.pid,
                pgid=handle.pgid,
                status=LifecycleState.RUNNING.value,
                workspace=str(context.workspace.workspace),
                stdout_path=str(stdout_path),
                stderr_path=str(stderr_path),
                argv=handle.argv,
                cwd=str(handle.cwd),
                created_at=message.timestamp,
                updated_at=message.timestamp,
                session_token=handle.session_token,
                live_token_path=str(handle.live_token_path),
            ))
            return envelope(
                message_type=HCOMType.SESSION_READY,
                source=self.provider_name,
                target="arbiter",
                payload={
                    "session_id": session_id,
                    "pid": handle.pid,
                    "pgid": handle.pgid,
                    "provider": self.provider_name,
                    "agent": task.agent,
                    "model": task.model,
                    "status": LifecycleState.RUNNING.value,
                    "stdout_path": str(stdout_path),
                    "stderr_path": str(stderr_path),
                },
                run_id=context.workspace.run_id,
                session_id=session_id,
                correlation_id=message.message_id,
            )
        result = self.supervisor.run(plan, timeout_seconds=timeout_seconds)
        if context.audit:
            context.audit.write("events", envelope(
                message_type=HCOMType.OUTPUT_FINAL if result.ok else HCOMType.ERROR,
                source=self.provider_name,
                target="arbiter",
                payload={
                    "task": task.to_dict(),
                    "returncode": result.returncode,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                },
                run_id=context.workspace.run_id,
                session_id=session_id,
                correlation_id=message.message_id,
            ).to_dict())
        return envelope(
            message_type=HCOMType.OUTPUT_FINAL if result.ok else HCOMType.ERROR,
            source=self.provider_name,
            target="arbiter",
            payload={
                "task": task.to_dict(),
                "returncode": result.returncode,
                "stdout": result.stdout,
                "stderr": result.stderr,
            },
            run_id=context.workspace.run_id,
            session_id=session_id,
            correlation_id=message.message_id,
        )

    def kill_hcom(self, session_id: str) -> HCOMEnvelope:
        self.supervisor.reap_children()
        self.sessions.reconcile()
        record = self.sessions.get(session_id)
        if record is None or record.provider != self.provider_name:
            raise ProviderError("session_not_found", f"unknown active session {session_id!r}")
        inspection = self.sessions.inspect(record)
        if (
            not inspection.running
            or not record.session_token
            or not record.live_token_path
            or not inspection.token_present
            or not inspection.token_matches
        ):
            self.sessions.remove(session_id)
            raise ProviderError("session_not_found", f"unknown active session {session_id!r}")
        self.sessions.update_status(session_id, LifecycleState.STOPPING.value)
        stopped = self.supervisor.terminate(record.pid, pgid=record.pgid, timeout_seconds=2.0)
        method = "terminate"
        if not stopped:
            stopped = self.supervisor.kill(record.pid, pgid=record.pgid, timeout_seconds=2.0)
            method = "kill"
        if not stopped:
            self.sessions.update_status(session_id, LifecycleState.RUNNING.value)
            raise ProviderError("session_stop_failed", f"failed to stop session {session_id!r}")
        self.sessions.remove(session_id)
        return envelope(
            message_type=HCOMType.SESSION_STOPPED,
            source=self.provider_name,
            target="arbiter",
            payload={
                "session_id": session_id,
                "provider": self.provider_name,
                "method": method,
                "pid": record.pid,
                "pgid": record.pgid,
                "status": LifecycleState.STOPPED.value,
            },
            run_id=record.run_id,
            session_id=session_id,
        )
