"""Persistent HCOM session registry."""

from __future__ import annotations

from dataclasses import asdict, dataclass
import errno
import json
import os
from pathlib import Path
import tempfile
from typing import Optional

from .audit import utc_now_iso
from .paths import ArbiterPaths


@dataclass(frozen=True)
class SessionRecord:
    session_id: str
    run_id: str
    provider: str
    agent: str
    model: str
    pid: int
    pgid: int
    status: str
    workspace: str
    stdout_path: str
    stderr_path: str
    argv: tuple[str, ...]
    cwd: str
    created_at: str
    updated_at: str
    session_token: str = ""
    live_token_path: str = ""

    @classmethod
    def from_dict(cls, data: dict[str, object]) -> "SessionRecord":
        return cls(
            session_id=str(data["session_id"]),
            run_id=str(data["run_id"]),
            provider=str(data["provider"]),
            agent=str(data.get("agent") or data["provider"]),
            model=str(data.get("model") or ""),
            pid=int(data["pid"]),
            pgid=int(data.get("pgid") or data["pid"]),
            status=str(data.get("status") or "running"),
            workspace=str(data["workspace"]),
            stdout_path=str(data["stdout_path"]),
            stderr_path=str(data["stderr_path"]),
            argv=tuple(str(item) for item in data.get("argv", [])),
            cwd=str(data.get("cwd") or data["workspace"]),
            created_at=str(data.get("created_at") or utc_now_iso()),
            updated_at=str(data.get("updated_at") or utc_now_iso()),
            session_token=str(data.get("session_token") or ""),
            live_token_path=str(data.get("live_token_path") or ""),
        )


@dataclass(frozen=True)
class SessionInspection:
    running: bool
    token_present: bool
    token_matches: bool
    detail: str


class SessionStore:
    def __init__(self, paths: ArbiterPaths) -> None:
        self.path = paths.path("state", "arbiter", "hcom", "sessions.json")

    @staticmethod
    def _has_persisted_token_metadata(record: SessionRecord) -> bool:
        return bool(record.session_token and record.live_token_path)

    def _load_raw(self) -> dict[str, dict[str, object]]:
        if not self.path.exists():
            return {}
        return json.loads(self.path.read_text(encoding="utf-8"))

    def _save(self, data: dict[str, dict[str, object]]) -> Path:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        fd, tmp_name = tempfile.mkstemp(prefix=".sessions.", suffix=".json", dir=str(self.path.parent))
        try:
            with open(fd, "w", encoding="utf-8", closefd=True) as handle:
                handle.write(json.dumps(data, indent=2, sort_keys=True) + "\n")
            Path(tmp_name).replace(self.path)
        finally:
            tmp = Path(tmp_name)
            if tmp.exists():
                tmp.unlink()
        return self.path

    def _load(self, *, reconcile: bool) -> dict[str, dict[str, object]]:
        data = self._load_raw()
        if not reconcile:
            return data
        changed = False
        for session_id, payload in list(data.items()):
            record = SessionRecord.from_dict(payload)
            inspection = self.inspect(record)
            if not self._should_remove(record, inspection):
                continue
            data.pop(session_id, None)
            changed = True
        if changed:
            self._save(data)
        return data

    def _should_remove(self, record: SessionRecord, inspection: SessionInspection) -> bool:
        if not inspection.running:
            return True
        if not self._has_persisted_token_metadata(record):
            return True
        return not inspection.token_present or not inspection.token_matches

    def _pid_running(self, pid: int) -> bool:
        try:
            os.kill(pid, 0)
            return True
        except OSError as exc:
            if exc.errno == errno.ESRCH:
                return False
            raise

    def _reap_direct_child(self, pid: int) -> bool:
        if pid <= 0:
            return False
        try:
            waited_pid, _ = os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            return False
        except OSError as exc:
            if exc.errno in (errno.ECHILD, errno.ESRCH):
                return False
            raise
        return waited_pid == pid

    def inspect(self, record: SessionRecord) -> SessionInspection:
        reaped = self._reap_direct_child(record.pid)
        running = False if reaped else self._pid_running(record.pid)
        token_present = False
        token_matches = False
        if record.live_token_path:
            token_path = Path(record.live_token_path)
            if token_path.exists():
                token_present = True
                token_matches = token_path.read_text(encoding="utf-8").strip() == record.session_token
        if not running:
            return SessionInspection(False, token_present, token_matches, "process not running")
        if not self._has_persisted_token_metadata(record):
            return SessionInspection(True, False, False, "persisted token metadata missing")
        if not token_present:
            return SessionInspection(True, False, False, "live token missing")
        if not token_matches:
            return SessionInspection(True, True, False, "live token mismatch")
        return SessionInspection(True, True, True, "session live")

    def reconcile(self) -> tuple[str, ...]:
        before = self._load_raw()
        after = self._load(reconcile=True)
        removed = sorted(set(before) - set(after))
        return tuple(removed)

    def list(self) -> tuple[SessionRecord, ...]:
        data = self._load(reconcile=True)
        return tuple(SessionRecord.from_dict(item) for item in data.values())

    def get(self, session_id: str) -> Optional[SessionRecord]:
        data = self._load(reconcile=True)
        item = data.get(session_id)
        return None if item is None else SessionRecord.from_dict(item)

    def put(self, record: SessionRecord) -> SessionRecord:
        data = self._load(reconcile=True)
        data[record.session_id] = asdict(record)
        self._save(data)
        return record

    def update_status(self, session_id: str, status: str) -> Optional[SessionRecord]:
        data = self._load(reconcile=True)
        item = data.get(session_id)
        if item is None:
            return None
        item = dict(item)
        item["status"] = status
        item["updated_at"] = utc_now_iso()
        data[session_id] = item
        self._save(data)
        return SessionRecord.from_dict(item)

    def remove(self, session_id: str) -> Optional[SessionRecord]:
        data = self._load(reconcile=False)
        item = data.pop(session_id, None)
        self._save(data)
        return None if item is None else SessionRecord.from_dict(item)
