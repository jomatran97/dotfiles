"""Provider process command planning and execution."""

from __future__ import annotations

from dataclasses import dataclass, field
import errno
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
from typing import ClassVar, Optional, Union
from uuid import uuid4

from .audit import Redactor


@dataclass(frozen=True)
class CommandPlan:
    argv: tuple[str, ...]
    cwd: Path
    env: dict[str, str] = field(default_factory=dict)
    provider: str = "unknown"
    run_id: Optional[str] = None
    description: Optional[str] = None

    def redacted(self) -> dict[str, object]:
        redactor = Redactor()
        return {
            "argv": list(self.argv),
            "cwd": str(self.cwd),
            "env": redactor.redact(self.env),
            "provider": self.provider,
            "run_id": self.run_id,
            "description": self.description,
        }


@dataclass(frozen=True)
class ProcessResult:
    argv: tuple[str, ...]
    cwd: Path
    returncode: int
    stdout: str
    stderr: str

    @property
    def ok(self) -> bool:
        return self.returncode == 0


@dataclass(frozen=True)
class ProcessHandle:
    pid: int
    pgid: int
    argv: tuple[str, ...]
    cwd: Path
    stdout_path: Path
    stderr_path: Path
    session_token: str
    live_token_path: Path


class ProcessSupervisor:
    """Small wrapper around subprocess for provider runs."""

    _children: ClassVar[dict[int, subprocess.Popen[str]]] = {}

    def run(
        self,
        plan: CommandPlan,
        *,
        input_text: Optional[str] = None,
        timeout_seconds: Optional[Union[int, float]] = None,
    ) -> ProcessResult:
        env = os.environ.copy()
        env.update(plan.env)
        completed = subprocess.run(
            list(plan.argv),
            cwd=str(plan.cwd),
            env=env,
            input=input_text,
            text=True,
            capture_output=True,
            timeout=timeout_seconds,
            check=False,
        )
        return ProcessResult(
            argv=plan.argv,
            cwd=plan.cwd,
            returncode=completed.returncode,
            stdout=completed.stdout,
            stderr=completed.stderr,
        )

    def reap_children(self) -> tuple[int, ...]:
        reaped: list[int] = []
        for pid, proc in list(self._children.items()):
            if proc.poll() is None:
                continue
            try:
                proc.wait(timeout=0)
            except subprocess.TimeoutExpired:
                continue
            self._children.pop(pid, None)
            reaped.append(pid)
        return tuple(reaped)

    def start(self, plan: CommandPlan, *, stdout_path: Path, stderr_path: Path) -> ProcessHandle:
        self.reap_children()
        env = os.environ.copy()
        env.update(plan.env)
        stdout_path.parent.mkdir(parents=True, exist_ok=True)
        stderr_path.parent.mkdir(parents=True, exist_ok=True)
        session_token = uuid4().hex
        live_token_path = stdout_path.parent / f".{stdout_path.stem}.{session_token}.live"
        fd, wrapper_name = tempfile.mkstemp(prefix=".arbiter-detached-", suffix=".sh", dir=str(stdout_path.parent))
        wrapper_path = Path(wrapper_name)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(
                "#!/usr/bin/env bash\n"
                "set -euo pipefail\n"
                "token_path=\"$1\"\n"
                "token=\"$2\"\n"
                "shift 2\n"
                "umask 077\n"
                "printf '%s\\n' \"$token\" > \"$token_path\"\n"
                "cleanup() {\n"
                "  rm -f \"$token_path\"\n"
                "}\n"
                "trap cleanup EXIT\n"
                "\"$@\" &\n"
                "child=$!\n"
                "wait \"$child\"\n"
            )
        wrapper_path.chmod(0o700)
        with stdout_path.open("a", encoding="utf-8") as stdout_handle, stderr_path.open("a", encoding="utf-8") as stderr_handle:
            proc = subprocess.Popen(
                [str(wrapper_path), str(live_token_path), session_token, *plan.argv],
                cwd=str(plan.cwd),
                env=env,
                text=True,
                stdin=subprocess.DEVNULL,
                stdout=stdout_handle,
                stderr=stderr_handle,
                start_new_session=True,
            )
        self._children[proc.pid] = proc
        deadline = time.monotonic() + 2.0
        while time.monotonic() < deadline:
            if live_token_path.exists() and live_token_path.read_text(encoding="utf-8").strip() == session_token:
                break
            if proc.poll() is not None:
                break
            time.sleep(0.02)
        pgid = proc.pid
        try:
            pgid = os.getpgid(proc.pid)
        except ProcessLookupError:
            if proc.poll() is None:
                raise
        except OSError as exc:
            if exc.errno != errno.ESRCH or proc.poll() is None:
                raise
        return ProcessHandle(proc.pid, pgid, plan.argv, plan.cwd, stdout_path, stderr_path, session_token, live_token_path)

    def is_running(self, pid: int) -> bool:
        self.reap_children()
        proc = self._children.get(pid)
        if proc is not None:
            return proc.poll() is None
        try:
            os.kill(pid, 0)
            return True
        except OSError as exc:
            if exc.errno == errno.ESRCH:
                return False
            raise

    def terminate(self, pid: int, *, pgid: Optional[int] = None, timeout_seconds: float = 5.0) -> bool:
        return self._stop(pid, pgid=pgid, sig=signal.SIGTERM, timeout_seconds=timeout_seconds)

    def kill(self, pid: int, *, pgid: Optional[int] = None, timeout_seconds: float = 5.0) -> bool:
        return self._stop(pid, pgid=pgid, sig=signal.SIGKILL, timeout_seconds=timeout_seconds)

    def _stop(self, pid: int, *, pgid: Optional[int], sig: signal.Signals, timeout_seconds: float) -> bool:
        self.reap_children()
        proc = self._children.get(pid)
        if proc is not None and proc.poll() is not None:
            self._children.pop(pid, None)
            return True
        if not self._signal_target(pid, pgid, sig):
            self._children.pop(pid, None)
            return True
        if proc is not None:
            try:
                proc.wait(timeout=timeout_seconds)
                return True
            except subprocess.TimeoutExpired:
                return False
            finally:
                if proc.poll() is not None:
                    self._children.pop(pid, None)
        stopped = self._wait_for_exit(pid, timeout_seconds=timeout_seconds)
        if stopped:
            self._children.pop(pid, None)
        return stopped

    def _signal_target(self, pid: int, pgid: Optional[int], sig: signal.Signals) -> bool:
        try:
            if pgid and pgid > 0:
                os.killpg(pgid, sig)
            else:
                os.kill(pid, sig)
            return True
        except ProcessLookupError:
            return False
        except OSError as exc:
            if exc.errno == errno.ESRCH:
                return False
            raise

    def _wait_for_exit(self, pid: int, *, timeout_seconds: float) -> bool:
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline:
            if not self.is_running(pid):
                return True
            time.sleep(0.1)
        return not self.is_running(pid)
