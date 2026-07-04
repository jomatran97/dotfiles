"""HCOM: provider-neutral message and task envelopes for Arbiter communication."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
import json
from pathlib import Path
from typing import Any, Mapping, Optional, Union
from uuid import uuid4

from .agents import AgentRegistryError, get_agent_spec
from .paths import ArbiterPaths

HCOM_SCHEMA_VERSION = "1.0"
TASK_SCHEMA_VERSION = "1.0"


class HCOMType(str, Enum):
    SESSION_PREPARE = "session.prepare"
    SESSION_READY = "session.ready"
    SESSION_START = "session.start"
    SESSION_STATE = "session.state"
    TASK_SUBMIT = "task.submit"
    OUTPUT_DELTA = "output.delta"
    OUTPUT_FINAL = "output.final"
    TOOL_EVENT = "tool.event"
    PERMISSION_REQUEST = "permission.request"
    PERMISSION_RESPONSE = "permission.response"
    ARTIFACT_CREATED = "artifact.created"
    ERROR = "error"
    SESSION_STOP = "session.stop"
    SESSION_STOPPED = "session.stopped"
    METRICS = "metrics"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


@dataclass(frozen=True)
class ContextIsolation:
    mode: str
    workspace_root: str
    provider_state_dir: str
    provider_log_dir: str
    artifact_dir: str
    allowed_paths: tuple[str, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "mode": self.mode,
            "workspace_root": self.workspace_root,
            "provider_state_dir": self.provider_state_dir,
            "provider_log_dir": self.provider_log_dir,
            "artifact_dir": self.artifact_dir,
            "allowed_paths": list(self.allowed_paths),
        }


@dataclass(frozen=True)
class TaskEnvelope:
    agent: str
    provider: str
    model: str
    prompt: str
    goal: str
    run_id: str
    workspace_root: str
    schema_version: str = TASK_SCHEMA_VERSION
    metadata: dict[str, Any] = field(default_factory=dict)
    isolation: Optional[ContextIsolation] = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "agent": self.agent,
            "provider": self.provider,
            "model": self.model,
            "prompt": self.prompt,
            "goal": self.goal,
            "run_id": self.run_id,
            "workspace_root": self.workspace_root,
            "metadata": self.metadata,
            "isolation": None if self.isolation is None else self.isolation.to_dict(),
        }

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "TaskEnvelope":
        isolation_data = data.get("isolation")
        isolation = None
        if isolation_data is not None:
            isolation = ContextIsolation(
                mode=str(isolation_data["mode"]),
                workspace_root=str(isolation_data["workspace_root"]),
                provider_state_dir=str(isolation_data["provider_state_dir"]),
                provider_log_dir=str(isolation_data["provider_log_dir"]),
                artifact_dir=str(isolation_data["artifact_dir"]),
                allowed_paths=tuple(str(item) for item in isolation_data.get("allowed_paths", [])),
            )
        return cls(
            schema_version=str(data.get("schema_version") or TASK_SCHEMA_VERSION),
            agent=str(data["agent"]),
            provider=str(data["provider"]),
            model=str(data["model"]),
            prompt=str(data["prompt"]),
            goal=str(data.get("goal") or "ad-hoc"),
            run_id=str(data["run_id"]),
            workspace_root=str(data["workspace_root"]),
            metadata=dict(data.get("metadata") or {}),
            isolation=isolation,
        )


@dataclass
class HCOMEnvelope:
    type: str
    source: str
    target: str
    payload: dict[str, Any]
    run_id: str
    schema_version: str = HCOM_SCHEMA_VERSION
    message_id: str = field(default_factory=lambda: str(uuid4()))
    correlation_id: Optional[str] = None
    session_id: Optional[str] = None
    timestamp: str = field(default_factory=utc_now_iso)
    redaction: dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.correlation_id:
            self.correlation_id = self.message_id

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "message_id": self.message_id,
            "correlation_id": self.correlation_id,
            "run_id": self.run_id,
            "session_id": self.session_id,
            "timestamp": self.timestamp,
            "source": self.source,
            "target": self.target,
            "type": self.type,
            "payload": self.payload,
            "redaction": self.redaction,
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), sort_keys=True, separators=(",", ":"))

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "HCOMEnvelope":
        required = ["type", "source", "target", "payload", "run_id"]
        missing = [key for key in required if key not in data]
        if missing:
            raise ValueError(f"missing HCOM fields: {', '.join(missing)}")
        return cls(
            schema_version=str(data.get("schema_version", HCOM_SCHEMA_VERSION)),
            message_id=str(data.get("message_id") or uuid4()),
            correlation_id=data.get("correlation_id"),
            run_id=str(data["run_id"]),
            session_id=data.get("session_id"),
            timestamp=str(data.get("timestamp") or utc_now_iso()),
            source=str(data["source"]),
            target=str(data["target"]),
            type=str(data["type"]),
            payload=dict(data["payload"]),
            redaction=dict(data.get("redaction") or {}),
        )


def envelope(
    *,
    message_type: Union[HCOMType, str],
    source: str,
    target: str,
    payload: Optional[dict[str, Any]],
    run_id: str,
    session_id: Optional[str] = None,
    correlation_id: Optional[str] = None,
    redaction: Optional[dict[str, Any]] = None,
) -> HCOMEnvelope:
    return HCOMEnvelope(
        type=message_type.value if isinstance(message_type, HCOMType) else str(message_type),
        source=source,
        target=target,
        payload=payload or {},
        run_id=run_id,
        session_id=session_id,
        correlation_id=correlation_id,
        redaction=redaction or {},
    )


def build_task_envelope(
    paths: ArbiterPaths,
    *,
    agent: str,
    prompt: str,
    goal: str,
    run_id: str,
    metadata: Optional[dict[str, Any]] = None,
) -> TaskEnvelope:
    spec = get_agent_spec(paths, agent)
    isolation = ContextIsolation(
        mode="provider-workspace-isolation",
        workspace_root=str(paths.root),
        provider_state_dir=str(paths.provider_state_dir(spec.provider)),
        provider_log_dir=str(paths.provider_log_dir(spec.provider)),
        artifact_dir=str(paths.provider_state_dir(spec.provider) / "artifacts" / run_id),
        allowed_paths=(
            str(paths.root),
            str(paths.provider_state_dir(spec.provider)),
            str(paths.provider_log_dir(spec.provider)),
        ),
    )
    return TaskEnvelope(
        agent=spec.name,
        provider=spec.provider,
        model=spec.model,
        prompt=prompt,
        goal=goal,
        run_id=run_id,
        workspace_root=str(paths.root),
        metadata=metadata or {},
        isolation=isolation,
    )


def assert_task_envelope(paths: ArbiterPaths, task: TaskEnvelope) -> None:
    if not task.prompt.strip():
        raise ValueError("task prompt must not be empty")
    if task.isolation is None:
        raise ValueError("task envelope requires structured context isolation")
    if Path(task.workspace_root).resolve() != paths.root.resolve():
        raise ValueError("task workspace_root does not match Arbiter root")
    try:
        spec = get_agent_spec(paths, task.agent)
    except AgentRegistryError as exc:
        raise ValueError(str(exc)) from exc
    if task.provider != spec.provider or task.model != spec.model:
        raise ValueError(
            "task envelope must match exact agent mapping for %s: %s/%s" % (spec.name, spec.provider, spec.model)
        )
