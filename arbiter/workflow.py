"""Compliant workflow runtime for Arbiter."""

from __future__ import annotations

from contextlib import contextmanager
from dataclasses import dataclass, field
from enum import Enum
import fcntl
import json
import os
import re
from pathlib import Path
import subprocess
import tempfile
from typing import Any, Dict, Iterator, List, Mapping, Optional, Sequence, Tuple
from uuid import uuid4

from .agents import get_agent_spec
from .audit import AuditLogger, utc_now_iso
from .gates import check_design_gate, check_requirements_gate, check_research_gate
from .hcom import HCOMType, build_task_envelope, envelope
from .paths import ArbiterPaths, REQUIRED_TOP_LEVEL_DIRS
from .startup import StartupCheck, validate_startup
from providers.registry import get_adapter


class WorkflowState(str, Enum):
    INIT = "INIT"
    PLAN = "PLAN"
    RESEARCH = "RESEARCH"
    REQUIREMENTS = "REQUIREMENTS"
    DESIGN = "DESIGN"
    IMPLEMENT = "IMPLEMENT"
    VERIFY = "VERIFY"
    AUDIT = "AUDIT"
    DEPLOY = "DEPLOY"
    MAINTENANCE = "MAINTENANCE"
    COMPLETE = "COMPLETE"
    FAILED = "FAILED"


WORKFLOW_SEQUENCE = (
    WorkflowState.INIT,
    WorkflowState.PLAN,
    WorkflowState.RESEARCH,
    WorkflowState.REQUIREMENTS,
    WorkflowState.DESIGN,
    WorkflowState.IMPLEMENT,
    WorkflowState.VERIFY,
    WorkflowState.AUDIT,
    WorkflowState.DEPLOY,
    WorkflowState.MAINTENANCE,
    WorkflowState.COMPLETE,
)

REFLECTION_ACTIONS = ("debug", "build", "verify", "audit")
ESCALATION_ACTIONS = ("trace", "craft", "plan", "build")
PHASE_AGENT_MAP = {
    WorkflowState.PLAN: "plan",
    WorkflowState.RESEARCH: "research",
    WorkflowState.REQUIREMENTS: "requirements",
    WorkflowState.DESIGN: "design",
    WorkflowState.IMPLEMENT: "implement",
    WorkflowState.VERIFY: "verify",
    WorkflowState.AUDIT: "audit",
    WorkflowState.DEPLOY: "deploy",
    WorkflowState.MAINTENANCE: "maintenance",
}
PHASE_ARTIFACT_MANIFEST = "index.json"
STATUS_PENDING = "Pending"
STATUS_IN_PROGRESS = "In Progress"
STATUS_REVIEW = "Review"
STATUS_COMPLETED = "Completed"
STATUS_FAILED = "Failed"
ACTION_PENDING = "pending"
ACTION_COMPLETED = "completed"


@dataclass(frozen=True)
class DeploymentCheck:
    name: str
    passed: bool
    detail: str


@dataclass(frozen=True)
class WorkflowAuditResult:
    passed: bool
    generated_at: str
    source: str
    checks: List[DeploymentCheck] = field(default_factory=list)

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "WorkflowAuditResult":
        return cls(
            passed=bool(data.get("passed", False)),
            generated_at=str(data.get("generated_at") or utc_now_iso()),
            source=str(data.get("source") or "unknown"),
            checks=[DeploymentCheck(str(item["name"]), bool(item.get("passed", False)), str(item.get("detail", ""))) for item in data.get("checks", [])],
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "passed": self.passed,
            "generated_at": self.generated_at,
            "source": self.source,
            "checks": [check.__dict__ for check in self.checks],
        }


@dataclass
class PhaseLifecycle:
    state: str
    status: str = STATUS_PENDING
    attempts: int = 0
    entered_at: Optional[str] = None
    completed_at: Optional[str] = None
    last_error: Optional[str] = None

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "PhaseLifecycle":
        return cls(
            state=_coerce_state_value(str(data["state"])),
            status=_coerce_status_value(str(data.get("status", STATUS_PENDING))),
            attempts=int(data.get("attempts", 0)),
            entered_at=data.get("entered_at"),
            completed_at=data.get("completed_at"),
            last_error=data.get("last_error"),
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "state": self.state,
            "status": self.status,
            "attempts": self.attempts,
            "entered_at": self.entered_at,
            "completed_at": self.completed_at,
            "last_error": self.last_error,
        }


@dataclass
class WorkflowGoal:
    goal_id: str
    target_state: str
    title: str
    status: str = "queued"
    attempts: int = 0
    max_attempts: int = 3
    created_at: str = field(default_factory=utc_now_iso)
    updated_at: str = field(default_factory=utc_now_iso)
    last_error: Optional[str] = None

    @property
    def target(self) -> WorkflowState:
        return WorkflowState(_coerce_state_value(self.target_state))

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "WorkflowGoal":
        return cls(
            goal_id=str(data["goal_id"]),
            target_state=_coerce_state_value(str(data["target_state"])),
            title=str(data["title"]),
            status=str(data.get("status", "queued")),
            attempts=int(data.get("attempts", 0)),
            max_attempts=max(1, int(data.get("max_attempts", 3))),
            created_at=str(data.get("created_at") or utc_now_iso()),
            updated_at=str(data.get("updated_at") or utc_now_iso()),
            last_error=data.get("last_error"),
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "goal_id": self.goal_id,
            "target_state": self.target_state,
            "title": self.title,
            "status": self.status,
            "attempts": self.attempts,
            "max_attempts": self.max_attempts,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
            "last_error": self.last_error,
        }


@dataclass
class WorkflowAction:
    name: str
    kind: str = "manual"
    phase: Optional[str] = None
    status: str = ACTION_PENDING
    completed_at: Optional[str] = None

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "WorkflowAction":
        return cls(
            name=str(data["name"]),
            kind=str(data.get("kind") or "manual"),
            phase=data.get("phase"),
            status=str(data.get("status") or ACTION_PENDING),
            completed_at=data.get("completed_at"),
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "kind": self.kind,
            "phase": self.phase,
            "status": self.status,
            "completed_at": self.completed_at,
        }


@dataclass(frozen=True)
class WorkflowCheckpointEvidence:
    goal_id: str
    action: str
    evidence: str
    source: str
    created_at: str
    path: str

    @classmethod
    def from_dict(cls, data: Mapping[str, Any], *, path: Path) -> "WorkflowCheckpointEvidence":
        return cls(
            goal_id=str(data["goal_id"]),
            action=str(data["action"]),
            evidence=str(data["evidence"]),
            source=str(data.get("source") or "manual"),
            created_at=str(data.get("created_at") or utc_now_iso()),
            path=str(path),
        )

    def to_dict(self) -> Dict[str, Any]:
        return {
            "goal_id": self.goal_id,
            "action": self.action,
            "evidence": self.evidence,
            "source": self.source,
            "created_at": self.created_at,
            "path": self.path,
        }


@dataclass
class QueueSnapshot:
    active: Optional[WorkflowGoal] = None
    pending: List[WorkflowGoal] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "active": None if self.active is None else self.active.to_dict(),
            "pending": [goal.to_dict() for goal in self.pending],
        }


@dataclass
class WorkflowSnapshot:
    current_state: WorkflowState
    updated_at: str
    phases: Dict[str, PhaseLifecycle]
    last_error: Optional[str] = None
    active_goal: Optional[WorkflowGoal] = None
    pending_goals: List[WorkflowGoal] = field(default_factory=list)
    required_actions: List[WorkflowAction] = field(default_factory=list)
    next_actions: List[str] = field(default_factory=list)
    branch_reason: Optional[str] = None

    @classmethod
    def from_dict(cls, data: Mapping[str, Any]) -> "WorkflowSnapshot":
        phases = {}
        for key, value in dict(data.get("phases", {})).items():
            lifecycle = PhaseLifecycle.from_dict(value)
            phases[_coerce_state_value(key)] = lifecycle

        snapshot = cls(
            current_state=WorkflowState(_coerce_state_value(str(data.get("current_state", WorkflowState.INIT.value)))),
            updated_at=str(data.get("updated_at") or utc_now_iso()),
            phases=phases,
            last_error=data.get("last_error"),
            required_actions=[WorkflowAction.from_dict(item) for item in data.get("required_actions", [])],
            next_actions=[str(item) for item in data.get("next_actions", [])],
            branch_reason=data.get("branch_reason"),
        )
        for state in WORKFLOW_SEQUENCE:
            if state.value in snapshot.phases:
                continue
            status = STATUS_COMPLETED if state_rank(state) <= state_rank(snapshot.current_state) else STATUS_PENDING
            snapshot.phases[state.value] = PhaseLifecycle(state=state.value, status=status)
        if data.get("active_goal"):
            snapshot.active_goal = WorkflowGoal.from_dict(data["active_goal"])
        snapshot.pending_goals = [WorkflowGoal.from_dict(item) for item in data.get("pending_goals", [])]
        return snapshot

    def to_dict(self) -> Dict[str, Any]:
        return {
            "current_state": self.current_state.value,
            "updated_at": self.updated_at,
            "phases": {key: value.to_dict() for key, value in self.phases.items()},
            "last_error": self.last_error,
            "active_goal": None if self.active_goal is None else self.active_goal.to_dict(),
            "pending_goals": [goal.to_dict() for goal in self.pending_goals],
            "required_actions": [action.to_dict() for action in self.required_actions],
            "next_actions": list(self.next_actions),
            "branch_reason": self.branch_reason,
        }


@dataclass
class WorkflowRunResult:
    passed: bool
    escalated: bool
    current_state: WorkflowState
    message: str
    goal: Optional[WorkflowGoal] = None
    checks: List[DeploymentCheck] = field(default_factory=list)
    branch: Optional[str] = None
    next_actions: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "passed": self.passed,
            "escalated": self.escalated,
            "current_state": self.current_state.value,
            "message": self.message,
            "goal": None if self.goal is None else self.goal.to_dict(),
            "checks": [check.__dict__ for check in self.checks],
            "branch": self.branch,
            "next_actions": list(self.next_actions),
        }


def _coerce_state_value(value: str) -> str:
    normalized = value.strip().upper()
    legacy = {
        "BOOTSTRAP": "INIT",
        "IMPLEMENTATION": "IMPLEMENT",
        "TESTING": "VERIFY",
        "DEPLOYMENT": "DEPLOY",
        "ESCALATED": "FAILED",
    }
    return legacy.get(normalized, normalized)


def _coerce_status_value(value: str) -> str:
    normalized = value.strip().lower()
    legacy = {
        "pending": STATUS_PENDING,
        "in progress": STATUS_IN_PROGRESS,
        "in_progress": STATUS_IN_PROGRESS,
        "review": STATUS_REVIEW,
        "completed": STATUS_COMPLETED,
        "failed": STATUS_FAILED,
    }
    return legacy.get(normalized, value)


def workflow_state_choices() -> Tuple[str, ...]:
    return tuple(state.value for state in (*WORKFLOW_SEQUENCE, WorkflowState.FAILED))


def state_rank(state: WorkflowState) -> int:
    if state == WorkflowState.FAILED:
        return len(WORKFLOW_SEQUENCE)
    return WORKFLOW_SEQUENCE.index(state)


def validate_transition(current: WorkflowState, new: WorkflowState) -> None:
    if current == new:
        return
    if new == WorkflowState.FAILED:
        return
    if current == WorkflowState.FAILED:
        raise ValueError("invalid workflow transition: FAILED blocks further progress until workflow-reset")
    current_rank = state_rank(current)
    allowed = WORKFLOW_SEQUENCE[current_rank + 1] if current_rank + 1 < len(WORKFLOW_SEQUENCE) else None
    if new != allowed:
        raise ValueError("invalid workflow transition: %s -> %s" % (current.value, new.value))


def next_state(current: WorkflowState) -> WorkflowState:
    if current == WorkflowState.FAILED:
        return WorkflowState.FAILED
    idx = state_rank(current)
    return current if idx + 1 >= len(WORKFLOW_SEQUENCE) else WORKFLOW_SEQUENCE[idx + 1]


def _workflow_dir(paths: ArbiterPaths) -> Path:
    return paths.state_dir / "arbiter" / "workflow"


def workflow_verify_result_path(paths: ArbiterPaths) -> Path:
    return _workflow_dir(paths) / "verify-result.json"


def workflow_audit_result_path(paths: ArbiterPaths) -> Path:
    return _workflow_dir(paths) / "audit-result.json"


def workflow_checkpoint_dir(paths: ArbiterPaths) -> Path:
    return _workflow_dir(paths) / "checkpoints"


def workflow_checkpoint_evidence_path(paths: ArbiterPaths, goal_id: str, action: str) -> Path:
    return workflow_checkpoint_dir(paths) / goal_id / f"{action}.json"


def workflow_phase_artifact_dir(paths: ArbiterPaths) -> Path:
    return _workflow_dir(paths) / "phase-artifacts"


def workflow_phase_artifact_path(paths: ArbiterPaths, goal_id: str, phase: str) -> Path:
    return workflow_phase_artifact_dir(paths) / goal_id / f"{_coerce_state_value(phase)}.json"


def workflow_phase_artifact_manifest_path(paths: ArbiterPaths, goal_id: str) -> Path:
    return workflow_phase_artifact_dir(paths) / goal_id / PHASE_ARTIFACT_MANIFEST


def read_workflow_phase_artifact(paths: ArbiterPaths, goal_id: str, phase: str) -> Optional[Dict[str, Any]]:
    path = workflow_phase_artifact_path(paths, goal_id, phase)
    if not path.exists():
        return None
    return dict(json.loads(path.read_text(encoding="utf-8")))


def read_workflow_phase_artifact_manifest(paths: ArbiterPaths, goal_id: str) -> Optional[Dict[str, Any]]:
    path = workflow_phase_artifact_manifest_path(paths, goal_id)
    if not path.exists():
        return None
    return dict(json.loads(path.read_text(encoding="utf-8")))


def _workflow_lock_path(paths: ArbiterPaths) -> Path:
    return _workflow_dir(paths) / ".lock"


@contextmanager
def _workflow_lock(paths: ArbiterPaths) -> Iterator[None]:
    directory = _workflow_dir(paths)
    directory.mkdir(parents=True, exist_ok=True)
    with _workflow_lock_path(paths).open("a+", encoding="utf-8") as handle:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def _atomic_write_text(path: Path, content: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_path, path)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)
    return path


def _append_jsonl_record(path: Path, event: Mapping[str, Any]) -> Path:
    existing = path.read_text(encoding="utf-8") if path.exists() else ""
    record = dict(event)
    record.setdefault("timestamp", utc_now_iso())
    return _atomic_write_text(path, existing + json.dumps(record, sort_keys=True, default=str) + "\n")


class WorkflowPersistence:
    def __init__(self, paths: ArbiterPaths) -> None:
        self.paths = paths
        self.directory = _workflow_dir(paths)
        self.state_path = self.directory / "state.json"
        self.history_path = self.directory / "history.jsonl"

    def load(self) -> WorkflowSnapshot:
        with _workflow_lock(self.paths):
            if not self.state_path.exists():
                snapshot = _initial_snapshot(self.paths)
                _atomic_write_text(self.state_path, json.dumps(snapshot.to_dict(), indent=2, sort_keys=True) + "\n")
                return snapshot
            return WorkflowSnapshot.from_dict(json.loads(self.state_path.read_text(encoding="utf-8")))

    def save(self, snapshot: WorkflowSnapshot) -> Path:
        with _workflow_lock(self.paths):
            return _atomic_write_text(self.state_path, json.dumps(snapshot.to_dict(), indent=2, sort_keys=True) + "\n")

    def append_history(self, event: Mapping[str, Any]) -> Path:
        with _workflow_lock(self.paths):
            return _append_jsonl_record(self.history_path, event)

    def reset_failure(self) -> WorkflowSnapshot:
        snapshot = self.load()
        if snapshot.current_state != WorkflowState.FAILED:
            return snapshot
        snapshot.current_state = _last_completed_state(snapshot)
        snapshot.last_error = None
        snapshot.branch_reason = None
        snapshot.required_actions = []
        snapshot.next_actions = []
        snapshot.updated_at = utc_now_iso()
        for lifecycle in snapshot.phases.values():
            if lifecycle.status == STATUS_FAILED:
                lifecycle.status = STATUS_PENDING
        self.save(snapshot)
        return snapshot


class WorkflowQueue:
    def __init__(self, paths: ArbiterPaths) -> None:
        self.paths = paths
        self.queue_path = _workflow_dir(paths) / "queue.json"

    def snapshot(self) -> QueueSnapshot:
        with _workflow_lock(self.paths):
            if not self.queue_path.exists():
                return QueueSnapshot()
            data = json.loads(self.queue_path.read_text(encoding="utf-8"))
            active = WorkflowGoal.from_dict(data["active"]) if data.get("active") else None
            pending = [WorkflowGoal.from_dict(item) for item in data.get("pending", [])]
            return QueueSnapshot(active=active, pending=pending)

    def save(self, snapshot: QueueSnapshot) -> Path:
        with _workflow_lock(self.paths):
            return _atomic_write_text(self.queue_path, json.dumps(snapshot.to_dict(), indent=2, sort_keys=True) + "\n")

    def enqueue(self, target_state: WorkflowState, title: str, max_attempts: int = 3) -> WorkflowGoal:
        current_state = WorkflowPersistence(self.paths).load().current_state
        if current_state == WorkflowState.FAILED:
            raise ValueError("workflow is FAILED; run workflow-reset before enqueueing a new goal")
        if target_state == WorkflowState.FAILED:
            raise ValueError("cannot enqueue FAILED as a target state")
        if state_rank(target_state) <= state_rank(current_state):
            raise ValueError("cannot enqueue target state %s because current persisted state is %s" % (target_state.value, current_state.value))
        snapshot = self.snapshot()
        goal = WorkflowGoal(
            goal_id=uuid4().hex,
            target_state=target_state.value,
            title=title,
            status="active" if snapshot.active is None else "queued",
            max_attempts=max(1, int(max_attempts)),
        )
        if snapshot.active is None:
            snapshot.active = goal
        else:
            snapshot.pending.append(goal)
        self.save(snapshot)
        return goal

    def update_active(self, goal: WorkflowGoal) -> None:
        snapshot = self.snapshot()
        snapshot.active = goal
        self.save(snapshot)

    def complete_active(self) -> QueueSnapshot:
        snapshot = self.snapshot()
        if snapshot.pending:
            active = snapshot.pending.pop(0)
            active.status = "active"
            active.updated_at = utc_now_iso()
            snapshot.active = active
        else:
            snapshot.active = None
        self.save(snapshot)
        return snapshot

    def clear_active(self) -> QueueSnapshot:
        snapshot = self.snapshot()
        snapshot.active = None
        self.save(snapshot)
        return snapshot


class WorkflowOrchestrator:
    def __init__(self, paths: ArbiterPaths) -> None:
        self.paths = paths
        self.persistence = WorkflowPersistence(paths)
        self.queue = WorkflowQueue(paths)
        self.audit = AuditLogger(paths.logs_dir / "arbiter")
        self.handlers = {
            WorkflowState.INIT: self._run_init,
            WorkflowState.PLAN: self._run_plan,
            WorkflowState.RESEARCH: self._run_research,
            WorkflowState.REQUIREMENTS: self._run_requirements,
            WorkflowState.DESIGN: self._run_design,
            WorkflowState.IMPLEMENT: self._run_implement,
            WorkflowState.VERIFY: self._run_verify,
            WorkflowState.AUDIT: self._run_audit,
            WorkflowState.DEPLOY: self._run_deploy,
            WorkflowState.MAINTENANCE: self._run_maintenance,
            WorkflowState.COMPLETE: self._run_complete,
        }

    def run_active(self) -> WorkflowRunResult:
        snapshot = self.persistence.load()
        queue_snapshot = self.queue.snapshot()
        snapshot.active_goal = queue_snapshot.active
        snapshot.pending_goals = list(queue_snapshot.pending)
        if snapshot.current_state == WorkflowState.FAILED:
            self.persistence.save(snapshot)
            update_todo_workflow_section(self.paths, snapshot)
            return WorkflowRunResult(False, True, snapshot.current_state, "workflow is FAILED; run workflow-reset before rerunning", goal=queue_snapshot.active)
        if queue_snapshot.active is None:
            update_todo_workflow_section(self.paths, snapshot)
            return WorkflowRunResult(True, False, snapshot.current_state, "no active workflow goal")

        goal = queue_snapshot.active
        checkpoint_result = self._run_pending_manual_action(snapshot, goal)
        if checkpoint_result is not None:
            self.persistence.save(snapshot)
            self.queue.update_active(goal)
            update_todo_workflow_section(self.paths, snapshot)
            return checkpoint_result
        last_checks: List[DeploymentCheck] = []
        while state_rank(snapshot.current_state) < state_rank(goal.target):
            target = next_state(snapshot.current_state)
            validate_transition(snapshot.current_state, target)
            lifecycle = snapshot.phases[target.value]
            lifecycle.status = STATUS_IN_PROGRESS
            lifecycle.attempts += 1
            lifecycle.entered_at = lifecycle.entered_at or utc_now_iso()
            snapshot.updated_at = utc_now_iso()
            snapshot.branch_reason = None
            snapshot.next_actions = []
            self.persistence.save(snapshot)
            self._audit("phase_start", snapshot.current_state, target, goal, None)
            phase_agent = self._dispatch_phase_agent(snapshot, goal, target)
            passed, message, checks = self.handlers[target]()
            if phase_agent is not None and phase_agent.get("status") == "failed" and os.environ.get("ARBITER_REQUIRE_PHASE_AGENTS") == "1":
                message = "phase agent failed: %s" % phase_agent.get("reason", "unknown error")
                checks = [DeploymentCheck("phase_agent", False, message), *checks]
                passed = False
            last_checks = list(checks)
            if passed:
                lifecycle.status = STATUS_COMPLETED if target != WorkflowState.AUDIT else STATUS_REVIEW
                lifecycle.completed_at = utc_now_iso()
                lifecycle.last_error = None
                snapshot.current_state = target
                snapshot.last_error = None
                if target == WorkflowState.AUDIT:
                    lifecycle.status = STATUS_COMPLETED
                self.persistence.append_history({"event": "phase_completed", "phase": target.value, "goal_id": goal.goal_id, "message": message})
                self._audit("phase_completed", snapshot.current_state, target, goal, message)
                checkpoint_result = self._complete_phase_action(snapshot, goal, target)
                if checkpoint_result is not None:
                    self.persistence.save(snapshot)
                    self.queue.update_active(goal)
                    update_todo_workflow_section(self.paths, snapshot)
                    return checkpoint_result
                continue
            goal.attempts += 1
            goal.last_error = message
            goal.updated_at = utc_now_iso()
            lifecycle.last_error = message
            lifecycle.status = STATUS_FAILED
            snapshot.last_error = message
            snapshot.updated_at = utc_now_iso()
            if target == WorkflowState.AUDIT:
                result = self._handle_audit_failure(snapshot, goal, checks, message)
                update_todo_workflow_section(self.paths, snapshot)
                return result
            if goal.attempts >= goal.max_attempts:
                snapshot.current_state = WorkflowState.FAILED
                snapshot.active_goal = None
                goal.status = "failed"
                self.persistence.append_history({"event": "phase_failed", "phase": target.value, "goal_id": goal.goal_id, "message": message})
                self.persistence.save(snapshot)
                self.queue.clear_active()
                update_todo_workflow_section(self.paths, snapshot)
                self._audit("phase_failed", WorkflowState.FAILED, target, goal, message)
                return WorkflowRunResult(False, True, snapshot.current_state, message, goal=goal, checks=checks)
            goal.status = "active"
            self.persistence.append_history({"event": "phase_failed", "phase": target.value, "goal_id": goal.goal_id, "message": message})
            self.persistence.save(snapshot)
            self.queue.update_active(goal)
            update_todo_workflow_section(self.paths, snapshot)
            self._audit("phase_retry", snapshot.current_state, target, goal, message)
            return WorkflowRunResult(False, False, snapshot.current_state, message, goal=goal, checks=checks)

        goal.status = "completed"
        self.persistence.append_history({"event": "goal_completed", "goal_id": goal.goal_id, "target_state": goal.target_state})
        queue_snapshot = self.queue.complete_active()
        snapshot.active_goal = queue_snapshot.active
        snapshot.pending_goals = list(queue_snapshot.pending)
        snapshot.required_actions = []
        snapshot.next_actions = []
        snapshot.branch_reason = None
        snapshot.updated_at = utc_now_iso()
        self.persistence.save(snapshot)
        update_todo_workflow_section(self.paths, snapshot)
        self._audit("goal_completed", snapshot.current_state, snapshot.current_state, goal, goal.title)
        return WorkflowRunResult(True, False, snapshot.current_state, goal.title, goal=goal, checks=last_checks)

    def _collect_labeled_block(self, lines: Sequence[str], label: str) -> Tuple[str, ...]:
        target = label.lower().rstrip(':')
        collected: List[str] = []
        active = False
        headings = {'summary', 'evidence', 'deliverables', 'next handoff'}
        for raw in lines:
            stripped = raw.strip()
            lower = stripped.lower()
            if lower.rstrip(':') in headings and (lower.endswith(':') or ':' not in lower):
                if lower.rstrip(':') == target:
                    active = True
                    continue
                if active:
                    break
            if active:
                collected.append(raw)
        return tuple(collected)

    def _normalize_bullets(self, lines: Sequence[str]) -> List[str]:
        items: List[str] = []
        for raw in lines:
            stripped = raw.strip()
            if not stripped:
                continue
            stripped = re.sub(r'^[-*]\s*', '', stripped)
            items.append(stripped)
        return items

    def _join_block(self, lines: Sequence[str]) -> str:
        return '\n'.join(line.rstrip() for line in lines).strip()

    def _structured_phase_output(self, phase: WorkflowState, *, status: str, text: str, reason: Optional[str] = None) -> Dict[str, Any]:
        raw = (text or '').strip()
        lines = raw.splitlines() if raw else []
        summary_block = self._collect_labeled_block(lines, 'Summary')
        evidence_block = self._collect_labeled_block(lines, 'Evidence')
        deliverables_block = self._collect_labeled_block(lines, 'Deliverables')
        next_block = self._collect_labeled_block(lines, 'Next handoff')

        summary = self._join_block(summary_block)
        if not summary:
            if raw:
                summary = raw.splitlines()[0].strip()
            elif reason:
                summary = reason.strip()
            else:
                summary = f'{phase.value} phase produced no provider output'

        evidence = self._normalize_bullets(evidence_block)
        if not evidence and reason and status != 'completed':
            evidence = [reason.strip()]

        deliverables = self._normalize_bullets(deliverables_block)
        next_handoff = self._join_block(next_block)
        if not next_handoff:
            if status == 'completed':
                next_handoff = f'Advance from {phase.value} using the persisted phase artifact.'
            elif status == 'skipped':
                next_handoff = f'Provider dispatch skipped; continue with repository phase gates for {phase.value}.'
            else:
                next_handoff = f'Review the {phase.value} phase artifact and failure reason before continuing.'

        return {
            'schema_version': '1.0',
            'status': status,
            'summary': summary,
            'evidence': evidence,
            'deliverables': deliverables,
            'next_handoff': next_handoff,
            'raw_text': raw,
        }

    def _provider_readiness_payload(self, readiness: Any) -> Dict[str, Any]:
        return {
            "provider": readiness.provider,
            "ready": readiness.ready,
            "identity": {
                "provider": readiness.identity.provider,
                "executable": readiness.identity.executable,
                "version": readiness.identity.version,
                "found": readiness.identity.found,
                "detail": readiness.identity.detail,
            },
            "auth": {
                "ready": readiness.auth.ready,
                "checked": readiness.auth.checked,
                "message": readiness.auth.message,
            },
            "capabilities": [
                {"name": item.name, "supported": item.supported, "detail": item.detail}
                for item in readiness.capabilities
            ],
            "errors": list(readiness.errors),
            "warnings": list(readiness.warnings),
        }

    def _goal_phase_artifact_files(self, goal: WorkflowGoal) -> List[Path]:
        directory = workflow_phase_artifact_dir(self.paths) / goal.goal_id
        if not directory.exists():
            return []
        return [path for path in sorted(directory.glob("*.json")) if path.name != PHASE_ARTIFACT_MANIFEST]

    def _load_phase_artifact_record(self, artifact_path: Path) -> Dict[str, Any]:
        payload = dict(json.loads(artifact_path.read_text(encoding="utf-8")))
        payload["artifact_path"] = str(artifact_path.relative_to(self.paths.root))
        payload["_path"] = artifact_path
        return payload

    def _phase_handoff_scorecard(self, artifact: Mapping[str, Any]) -> Dict[str, Any]:
        structured = dict(artifact.get("structured_output") or {})
        status = str(structured.get("status") or artifact.get("status") or "").lower()
        return {
            "status": status or "unknown",
            "status_rank": {"completed": 3, "skipped": 2, "failed": 1}.get(status, 0),
            "summary_rank": 1 if str(structured.get("summary") or "").strip() else 0,
            "evidence_count": len(list(structured.get("evidence") or [])),
            "deliverable_count": len(list(structured.get("deliverables") or [])),
            "created_at": str(artifact.get("created_at") or ""),
            "artifact_path": str(artifact.get("artifact_path") or ""),
        }

    def _phase_artifact_manifest_entry(self, artifact: Mapping[str, Any], *, archived: bool) -> Dict[str, Any]:
        structured = dict(artifact.get("structured_output") or {})
        score = self._phase_handoff_scorecard(artifact)
        return {
            "phase": self._phase_handoff_phase_name(artifact),
            "artifact": score["artifact_path"],
            "archived": archived,
            "status": score["status"],
            "created_at": score["created_at"],
            "summary": str(structured.get("summary") or ""),
            "evidence": list(structured.get("evidence") or []),
            "deliverables": list(structured.get("deliverables") or []),
            "next_handoff": str(structured.get("next_handoff") or ""),
            "evidence_count": score["evidence_count"],
            "deliverable_count": score["deliverable_count"],
            "has_summary": bool(score["summary_rank"]),
        }

    def _read_phase_artifact_manifest(self, goal: WorkflowGoal) -> Optional[Dict[str, Any]]:
        manifest_path = workflow_phase_artifact_manifest_path(self.paths, goal.goal_id)
        if not manifest_path.exists():
            return None
        return dict(json.loads(manifest_path.read_text(encoding="utf-8")))

    def _manifest_handoff_record(self, entry: Mapping[str, Any]) -> Dict[str, Any]:
        return {
            "phase": str(entry.get("phase") or "UNKNOWN"),
            "artifact_path": str(entry.get("artifact") or ""),
            "status": str(entry.get("status") or "unknown"),
            "created_at": str(entry.get("created_at") or ""),
            "structured_output": {
                "status": str(entry.get("status") or "unknown"),
                "summary": str(entry.get("summary") or ""),
                "evidence": list(entry.get("evidence") or []),
                "deliverables": list(entry.get("deliverables") or []),
                "next_handoff": str(entry.get("next_handoff") or ""),
            },
        }

    def _phase_handoff_artifacts_from_manifest(self, goal: WorkflowGoal, *, current_phase: WorkflowState, preferred: Sequence[str]) -> List[Dict[str, Any]]:
        manifest = self._read_phase_artifact_manifest(goal)
        if not manifest:
            return []
        entries: Dict[str, Mapping[str, Any]] = {}
        for item in list(manifest.get("active_artifacts") or []) + list(manifest.get("archived_artifacts") or []):
            artifact_path = str(item.get("artifact") or "")
            if artifact_path:
                entries[artifact_path] = item
        selected_records: List[Dict[str, Any]] = []
        for item in list(manifest.get("selection") or []):
            phase_name = str(item.get("phase") or "")
            if phase_name == current_phase.value:
                continue
            selected_artifact = str(item.get("selected_artifact") or "")
            entry = entries.get(selected_artifact)
            if entry is None:
                continue
            selected_records.append(self._manifest_handoff_record(entry))
        if not selected_records:
            return []
        ranked_records = sorted(selected_records, key=self._phase_handoff_sort_key, reverse=True)
        if not preferred:
            return ranked_records[:3]
        selected: List[Dict[str, Any]] = []
        for phase_name in preferred:
            matches = [record for record in ranked_records if self._phase_handoff_phase_name(record) == phase_name]
            if matches:
                selected.append(matches[0])
        if selected:
            return selected
        return ranked_records[:3]

    def _write_phase_artifact_manifest(self, goal: WorkflowGoal, *, preserve_phase: Optional[WorkflowState] = None, archived_this_run: Optional[Sequence[str]] = None) -> Path:
        directory = workflow_phase_artifact_dir(self.paths) / goal.goal_id
        directory.mkdir(parents=True, exist_ok=True)
        active_records = [self._load_phase_artifact_record(path) for path in self._goal_phase_artifact_files(goal)]
        archive_dir = directory / "archive"
        archived_records = []
        if archive_dir.exists():
            archived_records = [self._load_phase_artifact_record(path) for path in sorted(archive_dir.glob("*.json"))]
        all_records = [*active_records, *archived_records]
        grouped: Dict[str, List[Dict[str, Any]]] = {}
        for record in all_records:
            grouped.setdefault(self._phase_handoff_phase_name(record), []).append(record)
        selections: List[Dict[str, Any]] = []
        for phase_name in sorted(grouped):
            candidates = sorted(grouped[phase_name], key=self._phase_handoff_sort_key, reverse=True)
            selected = candidates[0]
            selected_path = Path(selected["_path"])
            active_for_phase = [record for record in active_records if self._phase_handoff_phase_name(record) == phase_name]
            archived_for_phase = [record for record in archived_records if self._phase_handoff_phase_name(record) == phase_name]
            reasons = ["best-ranked"]
            canonical_path = directory / f"{phase_name}.json"
            if selected_path == canonical_path:
                reasons.append("canonical")
            selections.append({
                "phase": phase_name,
                "candidate_count": len(candidates),
                "selected_artifact": str(selected_path.relative_to(self.paths.root)),
                "selected_status": self._phase_handoff_scorecard(selected)["status"],
                "selected_created_at": str(selected.get("created_at") or ""),
                "selected_reasons": reasons,
                "retained_active_artifacts": [str(Path(record["_path"]).relative_to(self.paths.root)) for record in sorted(active_for_phase, key=self._phase_handoff_sort_key, reverse=True)],
                "archived_artifacts": [str(Path(record["_path"]).relative_to(self.paths.root)) for record in sorted(archived_for_phase, key=self._phase_handoff_sort_key, reverse=True)],
            })
        payload = {
            "schema_version": "1.0",
            "goal_id": goal.goal_id,
            "updated_at": utc_now_iso(),
            "preserve_phase": preserve_phase.value if preserve_phase is not None else None,
            "retention": {
                "archived_this_run": list(archived_this_run or []),
                "ranking_policy": {
                    "status_order": ["completed", "skipped", "failed", "unknown"],
                    "tie_breakers": ["has_summary", "evidence_count", "deliverable_count", "created_at", "artifact_path"],
                },
            },
            "active_artifacts": [self._phase_artifact_manifest_entry(record, archived=False) for record in sorted(active_records, key=self._phase_handoff_sort_key, reverse=True)],
            "archived_artifacts": [self._phase_artifact_manifest_entry(record, archived=True) for record in sorted(archived_records, key=self._phase_handoff_sort_key, reverse=True)],
            "selection": selections,
        }
        manifest_path = workflow_phase_artifact_manifest_path(self.paths, goal.goal_id)
        _atomic_write_text(manifest_path, json.dumps(payload, indent=2, sort_keys=True) + "\n")
        return manifest_path

    def _phase_handoff_paths(self, goal: WorkflowGoal, *, current_phase: WorkflowState) -> List[str]:
        directory = workflow_phase_artifact_dir(self.paths) / goal.goal_id
        if not directory.exists():
            return []
        rels: List[str] = []
        for path in self._goal_phase_artifact_files(goal):
            if path.stem == current_phase.value:
                continue
            rels.append(str(path.relative_to(self.paths.root)))
        return rels

    def _archive_phase_artifact(self, artifact_path: Path, archive_dir: Path) -> Path:
        archive_dir.mkdir(parents=True, exist_ok=True)
        target = archive_dir / artifact_path.name
        if target.exists():
            target = archive_dir / f"{artifact_path.stem}-{uuid4().hex}{artifact_path.suffix}"
        artifact_path.rename(target)
        return target

    def _compact_phase_artifacts(self, goal: WorkflowGoal, *, preserve_phase: Optional[WorkflowState] = None) -> List[str]:
        directory = workflow_phase_artifact_dir(self.paths) / goal.goal_id
        if not directory.exists():
            return []
        records = [self._load_phase_artifact_record(path) for path in self._goal_phase_artifact_files(goal)]
        if len(records) < 2:
            return []
        keep_paths: set[Path] = set()
        if preserve_phase is not None:
            keep_paths.add(workflow_phase_artifact_path(self.paths, goal.goal_id, preserve_phase.value))
        grouped: Dict[str, List[Dict[str, Any]]] = {}
        for record in records:
            grouped.setdefault(self._phase_handoff_phase_name(record), []).append(record)
        for phase_name, group in grouped.items():
            ranked = sorted(group, key=self._phase_handoff_sort_key, reverse=True)
            keep_paths.add(Path(ranked[0]["_path"]))
            canonical = directory / f"{phase_name}.json"
            if canonical.exists():
                keep_paths.add(canonical)
        archive_dir = directory / "archive"
        archived: List[str] = []
        for record in records:
            artifact_path = Path(record["_path"])
            if artifact_path in keep_paths:
                continue
            archived_path = self._archive_phase_artifact(artifact_path, archive_dir)
            archived.append(str(archived_path.relative_to(self.paths.root)))
        return archived

    def _phase_handoff_phase_name(self, artifact: Mapping[str, Any]) -> str:
        return str(artifact.get("phase") or Path(str(artifact.get("artifact_path") or "UNKNOWN.json")).stem)

    def _phase_handoff_sort_key(self, artifact: Mapping[str, Any]) -> Tuple[int, int, int, int, str, str]:
        score = self._phase_handoff_scorecard(artifact)
        return (score["status_rank"], score["summary_rank"], score["evidence_count"], score["deliverable_count"], score["created_at"], score["artifact_path"])

    def _phase_handoff_artifacts(self, goal: WorkflowGoal, *, current_phase: WorkflowState) -> List[Dict[str, Any]]:
        directory = workflow_phase_artifact_dir(self.paths) / goal.goal_id
        if not directory.exists():
            return []
        relevance = {
            WorkflowState.PLAN: (WorkflowState.RESEARCH.value, WorkflowState.AUDIT.value, WorkflowState.VERIFY.value),
            WorkflowState.RESEARCH: (),
            WorkflowState.REQUIREMENTS: (WorkflowState.RESEARCH.value, WorkflowState.PLAN.value),
            WorkflowState.DESIGN: (WorkflowState.REQUIREMENTS.value, WorkflowState.RESEARCH.value, WorkflowState.PLAN.value),
            WorkflowState.IMPLEMENT: (WorkflowState.DESIGN.value, WorkflowState.REQUIREMENTS.value, WorkflowState.PLAN.value),
            WorkflowState.VERIFY: (WorkflowState.IMPLEMENT.value, WorkflowState.DESIGN.value, WorkflowState.REQUIREMENTS.value),
            WorkflowState.AUDIT: (WorkflowState.VERIFY.value, WorkflowState.IMPLEMENT.value, WorkflowState.DESIGN.value),
            WorkflowState.DEPLOY: (WorkflowState.AUDIT.value, WorkflowState.VERIFY.value),
            WorkflowState.MAINTENANCE: (WorkflowState.DEPLOY.value, WorkflowState.AUDIT.value, WorkflowState.VERIFY.value),
            WorkflowState.COMPLETE: (WorkflowState.MAINTENANCE.value, WorkflowState.DEPLOY.value, WorkflowState.AUDIT.value),
        }
        preferred = tuple(item for item in relevance.get(current_phase, ()) if item != current_phase.value)
        manifest_records = self._phase_handoff_artifacts_from_manifest(goal, current_phase=current_phase, preferred=preferred)
        if manifest_records:
            return manifest_records
        records: List[Dict[str, Any]] = []
        for artifact_path in self._goal_phase_artifact_files(goal):
            if artifact_path.stem == current_phase.value:
                continue
            payload = self._load_phase_artifact_record(artifact_path)
            records.append(payload)
        if not records:
            return []
        ranked_records = sorted(records, key=self._phase_handoff_sort_key, reverse=True)
        if not preferred:
            return ranked_records[:3]
        selected: List[Dict[str, Any]] = []
        for phase_name in preferred:
            matches = [record for record in ranked_records if self._phase_handoff_phase_name(record) == phase_name]
            if matches:
                selected.append(matches[0])
        if selected:
            return selected
        return ranked_records[:3]

    def _phase_focus_paths(self, phase: WorkflowState) -> List[str]:
        focus = {
            WorkflowState.PLAN: ['README.md', 'TODO.md', 'arbiter/REQUIREMENTS.md', 'arbiter/DESIGN.md'],
            WorkflowState.RESEARCH: ['research/claude.md', 'research/codex.md', 'research/antigravity.md'],
            WorkflowState.REQUIREMENTS: ['arbiter/REQUIREMENTS.md', 'README.md', 'TODO.md'],
            WorkflowState.DESIGN: ['arbiter/DESIGN.md', 'arbiter/REQUIREMENTS.md', 'providers/', 'arbiter/workflow.py'],
            WorkflowState.IMPLEMENT: ['arbiter/', 'providers/', 'tests/'],
            WorkflowState.VERIFY: ['scripts/test-arbiter', 'tests/harness.sh', 'tests/'],
            WorkflowState.AUDIT: ['state/arbiter/workflow/verify-result.json', 'state/arbiter/workflow/audit-result.json', 'logs/arbiter/workflow.jsonl'],
            WorkflowState.DEPLOY: ['arbiter/DEPLOYMENT.md', 'state/arbiter/workflow/audit-result.json', 'README.md'],
            WorkflowState.MAINTENANCE: ['arbiter/MAINTENANCE.md', 'TODO.md', 'research/'],
        }
        return list(focus.get(phase, []))

    def _phase_command_hints(self, phase: WorkflowState) -> List[str]:
        hints = {
            WorkflowState.PLAN: ['./scripts/arbiter workflow-state --json'],
            WorkflowState.RESEARCH: ['./scripts/arbiter startup-validate --json'],
            WorkflowState.REQUIREMENTS: ['./scripts/arbiter check-gates --json'],
            WorkflowState.DESIGN: ['./scripts/arbiter agents --json', './scripts/arbiter providers --json'],
            WorkflowState.IMPLEMENT: ['./scripts/test-arbiter'],
            WorkflowState.VERIFY: ['./scripts/test-arbiter', './tests/harness.sh'],
            WorkflowState.AUDIT: ['./scripts/arbiter workflow-state --json'],
            WorkflowState.DEPLOY: ['./scripts/arbiter workflow-state --json', './scripts/arbiter doctor --json'],
            WorkflowState.MAINTENANCE: ['./scripts/arbiter workflow-state --json'],
        }
        return list(hints.get(phase, []))

    def _phase_expected_output(self, phase: WorkflowState) -> List[str]:
        expected = {
            WorkflowState.PLAN: ['ordered plan', 'phase risks', 'next handoff'],
            WorkflowState.RESEARCH: ['verified findings', 'unknowns', 'next handoff'],
            WorkflowState.REQUIREMENTS: ['requirements delta', 'acceptance criteria', 'next handoff'],
            WorkflowState.DESIGN: ['design decisions', 'invariants', 'next handoff'],
            WorkflowState.IMPLEMENT: ['changed paths', 'implementation summary', 'next handoff'],
            WorkflowState.VERIFY: ['commands run', 'pass/fail summary', 'next handoff'],
            WorkflowState.AUDIT: ['findings with severity', 'pass/fail decision', 'next handoff'],
            WorkflowState.DEPLOY: ['deployment readiness summary', 'remaining blockers', 'next handoff'],
            WorkflowState.MAINTENANCE: ['maintenance checklist', 'drift follow-ups', 'next handoff'],
        }
        return list(expected.get(phase, ['phase summary', 'next handoff']))

    def _build_phase_prompt(self, snapshot: WorkflowSnapshot, goal: WorkflowGoal, phase: WorkflowState, agent_name: str) -> str:
        handoffs = self._phase_handoff_paths(goal, current_phase=phase)
        handoff_artifacts = self._phase_handoff_artifacts(goal, current_phase=phase)
        focus_paths = self._phase_focus_paths(phase)
        command_hints = self._phase_command_hints(phase)
        expected_output = self._phase_expected_output(phase)
        lines = [
            f"Workflow phase: {phase.value}",
            f"Assigned agent: {agent_name}",
            f"Goal id: {goal.goal_id}",
            f"Goal title: {goal.title}",
            f"Target state: {goal.target_state}",
            f"Current persisted state before phase: {snapshot.current_state.value}",
            f"Repository root: {self.paths.root}",
            "",
            "Produce output that follows the checked-in agent contract.",
            "Use exact repository paths when referencing evidence or follow-up work.",
            "Keep the response concise, operational, and ready for the next workflow handoff.",
        ]
        if snapshot.branch_reason:
            lines.extend(["", f"Current branch reason: {snapshot.branch_reason}"])
        if snapshot.next_actions:
            lines.extend(["", "Pending workflow actions: " + ", ".join(snapshot.next_actions)])
        if snapshot.last_error:
            lines.extend(["", f"Last workflow error: {snapshot.last_error}"])
        if handoffs:
            lines.extend(["", "Prior phase artifacts:"])
            lines.extend(f"- {item}" for item in handoffs)
        if handoff_artifacts:
            lines.extend(["", "Prior structured handoffs:"])
            for artifact in handoff_artifacts:
                structured = dict(artifact.get("structured_output") or {})
                lines.append(f"- {artifact.get('phase', 'UNKNOWN')} via {artifact['artifact_path']}")
                lines.append(f"  status: {structured.get('status') or artifact.get('status', 'unknown')}")
                if structured.get('summary'):
                    lines.append(f"  summary: {structured['summary']}")
                evidence = list(structured.get('evidence') or [])[:3]
                if evidence:
                    lines.append("  evidence:")
                    lines.extend(f"    - {item}" for item in evidence)
                deliverables = list(structured.get('deliverables') or [])[:3]
                if deliverables:
                    lines.append("  deliverables:")
                    lines.extend(f"    - {item}" for item in deliverables)
                if structured.get('next_handoff'):
                    lines.append(f"  next handoff: {structured['next_handoff']}")
        if focus_paths:
            lines.extend(["", "Focus paths:"])
            lines.extend(f"- {item}" for item in focus_paths)
        if command_hints:
            lines.extend(["", "Command hints:"])
            lines.extend(f"- {item}" for item in command_hints)
        lines.extend([
            "",
            "Expected output schema (use these exact headings):",
            "Summary:",
            "- one short paragraph",
            "Evidence:",
            "- bullet list with exact paths or command results",
            "Deliverables:",
            "- " + "\n- ".join(expected_output),
            "Next handoff:",
            "- explicit next phase, checkpoint, or artifact consumer",
            "",
            "Return a concise phase-ready result and explicit handoff notes for the next step.",
        ])
        return "\n".join(lines).strip()

    def _dispatch_phase_agent(self, snapshot: WorkflowSnapshot, goal: WorkflowGoal, phase: WorkflowState) -> Optional[Dict[str, Any]]:
        agent_name = PHASE_AGENT_MAP.get(phase)
        if not agent_name:
            return None
        spec = get_agent_spec(self.paths, agent_name)
        adapter = get_adapter(spec.provider, self.paths)
        readiness = adapter.check_readiness()
        archived_artifacts = self._compact_phase_artifacts(goal, preserve_phase=phase)
        prompt = self._build_phase_prompt(snapshot, goal, phase, spec.name)
        artifact = {
            "goal_id": goal.goal_id,
            "goal_title": goal.title,
            "phase": phase.value,
            "agent": spec.name,
            "provider": spec.provider,
            "model": spec.model,
            "created_at": utc_now_iso(),
            "prompt": prompt,
            "readiness": self._provider_readiness_payload(readiness),
            "status": "skipped",
            "retention": {"archived": archived_artifacts},
        }
        path = workflow_phase_artifact_path(self.paths, goal.goal_id, phase.value)
        if not readiness.ready:
            reason = "; ".join(list(readiness.errors) or list(readiness.warnings) or ["provider not ready"])
            artifact["reason"] = reason
            artifact["structured_output"] = self._structured_phase_output(phase, status="skipped", text="", reason=reason)
            _atomic_write_text(path, json.dumps(artifact, indent=2, sort_keys=True) + "\n")
            self._write_phase_artifact_manifest(goal, preserve_phase=phase, archived_this_run=archived_artifacts)
            self.persistence.append_history({"event": "phase_agent_skipped", "phase": phase.value, "goal_id": goal.goal_id, "agent": spec.name, "reason": reason})
            self._audit("phase_agent_skipped", snapshot.current_state, phase, goal, reason)
            return artifact
        try:
            context = adapter.prepare_context(run_id=f"workflow-{goal.goal_id[:8]}-{phase.value.lower()}", dry_run=False)
            manifest = adapter.materialize_config(context)
            task = build_task_envelope(
                self.paths,
                agent=spec.name,
                prompt=prompt,
                goal=goal.title,
                run_id=context.workspace.run_id,
                metadata={"source": "workflow.phase", "phase": phase.value, "goal_id": goal.goal_id},
            )
            message = envelope(
                message_type=HCOMType.TASK_SUBMIT,
                source="arbiter",
                target=spec.provider,
                payload={"task": task.to_dict()},
                run_id=context.workspace.run_id,
            )
            response = adapter.send_hcom(context, message, detached=False, timeout_seconds=90)
            artifact.update({
                "status": "completed" if response.type != HCOMType.ERROR.value else "failed",
                "run_id": context.workspace.run_id,
                "task": task.to_dict(),
                "response": response.to_dict(),
                "materialization": manifest.to_dict(),
            })
            if artifact["status"] == "failed":
                artifact["reason"] = str(response.payload.get("stderr") or response.payload.get("stdout") or "phase agent returned error")
            provider_text = str(response.payload.get("stdout") or response.payload.get("stderr") or "")
            artifact["structured_output"] = self._structured_phase_output(phase, status=str(artifact["status"]), text=provider_text, reason=artifact.get("reason"))
        except Exception as exc:
            artifact.update({
                "status": "failed",
                "reason": str(exc),
                "error": {"type": exc.__class__.__name__, "message": str(exc)},
            })
            artifact["structured_output"] = self._structured_phase_output(phase, status="failed", text="", reason=str(exc))
        _atomic_write_text(path, json.dumps(artifact, indent=2, sort_keys=True, default=str) + "\n")
        self._write_phase_artifact_manifest(goal, preserve_phase=phase, archived_this_run=archived_artifacts)
        history_event = "phase_agent_completed" if artifact["status"] == "completed" else "phase_agent_failed"
        self.persistence.append_history({
            "event": history_event,
            "phase": phase.value,
            "goal_id": goal.goal_id,
            "agent": spec.name,
            "status": artifact["status"],
            "artifact": str(path.relative_to(self.paths.root)),
            "reason": artifact.get("reason"),
        })
        self._audit(history_event, snapshot.current_state, phase, goal, artifact.get("reason") or artifact["status"])
        return artifact

    def _handle_audit_failure(
        self,
        snapshot: WorkflowSnapshot,
        goal: WorkflowGoal,
        checks: List[DeploymentCheck],
        message: str,
    ) -> WorkflowRunResult:
        if goal.attempts == 1:
            snapshot.current_state = WorkflowState.IMPLEMENT
            snapshot.branch_reason = "PASS/FAIL branch: audit -> debug -> build -> verify -> audit"
            snapshot.required_actions = self._reflection_actions()
            snapshot.next_actions = self._pending_action_names(snapshot)
            self._set_pending_from(snapshot, WorkflowState.IMPLEMENT)
            self.persistence.append_history({"event": "audit_reflection", "goal_id": goal.goal_id, "actions": list(REFLECTION_ACTIONS), "message": message})
            self.persistence.save(snapshot)
            self.queue.update_active(goal)
            self._audit("audit_reflection", snapshot.current_state, WorkflowState.AUDIT, goal, message)
            return WorkflowRunResult(False, False, snapshot.current_state, message, goal=goal, checks=checks, branch="reflection", next_actions=self._pending_action_names(snapshot))
        if goal.attempts < goal.max_attempts:
            snapshot.current_state = WorkflowState.PLAN
            snapshot.branch_reason = "PASS/FAIL branch: audit -> trace -> craft -> updated plan -> build"
            snapshot.required_actions = self._escalation_actions()
            snapshot.next_actions = self._pending_action_names(snapshot)
            self._set_pending_from(snapshot, WorkflowState.PLAN)
            self.persistence.append_history({"event": "audit_escalation", "goal_id": goal.goal_id, "actions": list(ESCALATION_ACTIONS), "message": message})
            self.persistence.save(snapshot)
            self.queue.update_active(goal)
            self._audit("audit_escalation", snapshot.current_state, WorkflowState.AUDIT, goal, message)
            return WorkflowRunResult(False, False, snapshot.current_state, message, goal=goal, checks=checks, branch="escalation", next_actions=self._pending_action_names(snapshot))
        snapshot.current_state = WorkflowState.FAILED
        goal.status = "failed"
        snapshot.required_actions = []
        snapshot.next_actions = []
        snapshot.branch_reason = None
        self.persistence.save(snapshot)
        self.queue.clear_active()
        self._audit("audit_failed", snapshot.current_state, WorkflowState.AUDIT, goal, message)
        return WorkflowRunResult(False, True, snapshot.current_state, message, goal=goal, checks=checks, branch="failed")

    def _reflection_actions(self) -> List[WorkflowAction]:
        return [
            WorkflowAction("debug", kind="manual"),
            WorkflowAction("build", kind="manual"),
            WorkflowAction("verify", kind="phase", phase=WorkflowState.VERIFY.value),
            WorkflowAction("audit", kind="phase", phase=WorkflowState.AUDIT.value),
        ]

    def _escalation_actions(self) -> List[WorkflowAction]:
        return [WorkflowAction(name, kind="manual") for name in ESCALATION_ACTIONS]

    def _branch_name(self, snapshot: WorkflowSnapshot) -> Optional[str]:
        names = tuple(action.name for action in snapshot.required_actions)
        if names == REFLECTION_ACTIONS:
            return "reflection"
        if names == ESCALATION_ACTIONS:
            return "escalation"
        return None

    def _pending_action_names(self, snapshot: WorkflowSnapshot) -> List[str]:
        return [action.name for action in snapshot.required_actions if action.status != ACTION_COMPLETED]

    def _mark_action_completed(self, snapshot: WorkflowSnapshot, action: WorkflowAction) -> List[str]:
        action.status = ACTION_COMPLETED
        action.completed_at = utc_now_iso()
        snapshot.next_actions = self._pending_action_names(snapshot)
        if not snapshot.next_actions:
            snapshot.branch_reason = None
        snapshot.updated_at = utc_now_iso()
        return list(snapshot.next_actions)

    def _run_pending_manual_action(self, snapshot: WorkflowSnapshot, goal: WorkflowGoal) -> Optional[WorkflowRunResult]:
        for action in snapshot.required_actions:
            if action.status == ACTION_COMPLETED:
                continue
            if action.kind != "manual":
                return None
            evidence = read_workflow_checkpoint_evidence(self.paths, goal.goal_id, action.name)
            if evidence is None:
                snapshot.next_actions = self._pending_action_names(snapshot)
                snapshot.updated_at = utc_now_iso()
                artifact = workflow_checkpoint_evidence_path(self.paths, goal.goal_id, action.name).relative_to(self.paths.root)
                message = f"workflow checkpoint blocked: {action.name} requires explicit persisted evidence at {artifact}"
                self.persistence.append_history({"event": "checkpoint_blocked", "action": action.name, "kind": action.kind, "goal_id": goal.goal_id, "state": snapshot.current_state.value, "artifact": str(artifact)})
                self._audit("checkpoint_blocked", snapshot.current_state, snapshot.current_state, goal, message)
                return WorkflowRunResult(False, False, snapshot.current_state, message, goal=goal, branch=self._branch_name(snapshot), next_actions=snapshot.next_actions)
            remaining = self._mark_action_completed(snapshot, action)
            if action.name == "build":
                snapshot.current_state = WorkflowState.IMPLEMENT
                lifecycle = snapshot.phases[WorkflowState.IMPLEMENT.value]
                lifecycle.status = STATUS_COMPLETED
                lifecycle.completed_at = action.completed_at
                lifecycle.last_error = None
                lifecycle.attempts = max(lifecycle.attempts, 1)
            message = f"workflow checkpoint completed: {action.name}"
            self.persistence.append_history({"event": "checkpoint_completed", "action": action.name, "kind": action.kind, "goal_id": goal.goal_id, "state": snapshot.current_state.value, "remaining": remaining, "evidence_path": evidence.path, "evidence_source": evidence.source})
            self._audit("checkpoint_completed", snapshot.current_state, snapshot.current_state, goal, message)
            return WorkflowRunResult(False, False, snapshot.current_state, message, goal=goal, branch=self._branch_name(snapshot), next_actions=remaining)
        return None

    def _complete_phase_action(self, snapshot: WorkflowSnapshot, goal: WorkflowGoal, target: WorkflowState) -> Optional[WorkflowRunResult]:
        for action in snapshot.required_actions:
            if action.status == ACTION_COMPLETED:
                continue
            if action.kind == "phase" and action.phase == target.value:
                remaining = self._mark_action_completed(snapshot, action)
                message = f"workflow checkpoint completed: {action.name}"
                self.persistence.append_history({"event": "checkpoint_completed", "action": action.name, "kind": action.kind, "goal_id": goal.goal_id, "state": snapshot.current_state.value, "remaining": remaining})
                self._audit("checkpoint_completed", snapshot.current_state, target, goal, message)
                if remaining:
                    return WorkflowRunResult(False, False, snapshot.current_state, message, goal=goal, branch=self._branch_name(snapshot), next_actions=remaining)
                return None
        return None

    def _set_pending_from(self, snapshot: WorkflowSnapshot, state: WorkflowState) -> None:
        for phase in WORKFLOW_SEQUENCE:
            lifecycle = snapshot.phases[phase.value]
            if phase == WorkflowState.COMPLETE:
                lifecycle.status = STATUS_PENDING
                lifecycle.completed_at = None
                continue
            if state_rank(phase) >= state_rank(state):
                lifecycle.status = STATUS_PENDING if phase != WorkflowState.AUDIT else STATUS_REVIEW
                lifecycle.completed_at = None

    def _audit(self, event: str, current: WorkflowState, target: WorkflowState, goal: Optional[WorkflowGoal], message: Optional[str]) -> None:
        self.audit.write("workflow", {
            "event": event,
            "current_state": current.value,
            "target_state": target.value,
            "goal_id": None if goal is None else goal.goal_id,
            "goal_title": None if goal is None else goal.title,
            "message": message,
        })

    def _run_init(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        self.paths.ensure_standard_layout()
        return True, "workspace layout ensured", []

    def _run_plan(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        checks = [DeploymentCheck(item.name, item.passed, item.detail) for item in validate_startup(self.paths)]
        failed = [check for check in checks if not check.passed]
        return (not failed, "plan ready" if not failed else "; ".join(check.detail for check in failed), checks)

    def _run_research(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        result = check_research_gate(self.paths)
        return result.passed, _gate_message(result.name, result.passed, result.missing), []

    def _run_requirements(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        result = check_requirements_gate(self.paths)
        return result.passed, _gate_message(result.name, result.passed, result.missing), []

    def _run_design(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        result = check_design_gate(self.paths)
        return result.passed, _gate_message(result.name, result.passed, result.missing), []

    def _run_implement(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        required = [self.paths.path("arbiter", name) for name in ("cli.py", "workflow.py", "hcom.py", "agents.py")]
        missing = [str(path.relative_to(self.paths.root)) for path in required if not path.exists()]
        passed = not missing
        return passed, "implementation architecture present" if passed else "missing: %s" % ", ".join(missing), []

    def _run_verify(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        result = write_verify_result(self.paths, source="VERIFY")
        failed = [check for check in result.checks if not check.passed]
        return (not failed, "verify passed" if not failed else "; ".join(check.detail for check in failed), result.checks)

    def _run_audit(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        result = write_workflow_audit_result(self.paths, source="AUDIT")
        failed = [check for check in result.checks if not check.passed]
        return (not failed, "audit passed" if not failed else "; ".join(check.detail for check in failed), result.checks)

    def _run_deploy(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        checks = check_deployment_gate(self.paths)
        failed = [check for check in checks if not check.passed]
        return (not failed, "deployment gate passed" if not failed else "; ".join(check.detail for check in failed), checks)

    def _run_maintenance(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        path = self.paths.path("arbiter", "MAINTENANCE.md")
        passed = path.exists()
        return passed, "maintenance plan present" if passed else "maintenance gate failed; missing arbiter/MAINTENANCE.md", []

    def _run_complete(self) -> Tuple[bool, str, List[DeploymentCheck]]:
        return True, "workflow complete", []

    def reset(self) -> WorkflowSnapshot:
        snapshot = self.persistence.reset_failure()
        queue_snapshot = self.queue.snapshot()
        snapshot.active_goal = queue_snapshot.active
        snapshot.pending_goals = list(queue_snapshot.pending)
        snapshot.updated_at = utc_now_iso()
        self.persistence.save(snapshot)
        update_todo_workflow_section(self.paths, snapshot)
        return snapshot


def _gate_message(name: str, passed: bool, missing: Sequence[str]) -> str:
    return "%s gate passed" % name if passed else "%s gate failed; missing: %s" % (name, ", ".join(missing))


def _run_shell_script(script: Path, root: Path) -> subprocess.CompletedProcess:
    env = os.environ.copy()
    existing = env.get("PYTHONPATH")
    env["PYTHONPATH"] = str(root) if not existing else str(root) + os.pathsep + existing
    return subprocess.run(["bash", str(script)], cwd=str(root), env=env, text=True, capture_output=True, check=False)


def _workflow_verification_checks(paths: ArbiterPaths) -> List[DeploymentCheck]:
    checks: List[DeploymentCheck] = []
    test_script = paths.path("scripts", "test-arbiter")
    if not test_script.exists():
        checks.append(DeploymentCheck("tests", False, "deployment gate failed; missing scripts/test-arbiter"))
    else:
        completed = _run_shell_script(test_script, paths.root)
        checks.append(DeploymentCheck("tests", completed.returncode == 0, "test suite passed" if completed.returncode == 0 else "deployment gate failed; test suite returned %s" % completed.returncode))
    harness_script = paths.path("tests", "harness.sh")
    if not harness_script.exists():
        checks.append(DeploymentCheck("harness", False, "deployment gate failed; missing tests/harness.sh"))
    else:
        completed = _run_shell_script(harness_script, paths.root)
        checks.append(DeploymentCheck("harness", completed.returncode == 0, "harness passed" if completed.returncode == 0 else "deployment gate failed; harness returned %s" % completed.returncode))
    return checks


def _serialize_result(path: Path, result: WorkflowAuditResult) -> WorkflowAuditResult:
    with _workflow_lock(ArbiterPaths(path.parents[3])):
        _atomic_write_text(path, json.dumps(result.to_dict(), indent=2, sort_keys=True) + "\n")
    return result


def write_verify_result(paths: ArbiterPaths, *, source: str) -> WorkflowAuditResult:
    checks = _workflow_verification_checks(paths)
    result = WorkflowAuditResult(all(check.passed for check in checks), utc_now_iso(), source, checks)
    _atomic_write_text(workflow_verify_result_path(paths), json.dumps(result.to_dict(), indent=2, sort_keys=True) + "\n")
    return result


def read_verify_result(paths: ArbiterPaths) -> Optional[WorkflowAuditResult]:
    path = workflow_verify_result_path(paths)
    if not path.exists():
        return None
    return WorkflowAuditResult.from_dict(json.loads(path.read_text(encoding="utf-8")))


def write_workflow_audit_result(paths: ArbiterPaths, *, source: str) -> WorkflowAuditResult:
    checks: List[DeploymentCheck] = []
    verify = read_verify_result(paths)
    verify_ok = verify is not None and verify.passed
    checks.append(DeploymentCheck("verify", verify_ok, "verify artifact passed" if verify_ok else "missing or failing verify artifact at %s" % workflow_verify_result_path(paths).relative_to(paths.root)))
    startup_checks = validate_startup(paths)
    checks.extend(DeploymentCheck(check.name, check.passed, check.detail) for check in startup_checks)
    result = WorkflowAuditResult(all(check.passed for check in checks), utc_now_iso(), source, checks)
    _atomic_write_text(workflow_audit_result_path(paths), json.dumps(result.to_dict(), indent=2, sort_keys=True) + "\n")
    return result


def read_workflow_audit_result(paths: ArbiterPaths) -> Optional[WorkflowAuditResult]:
    path = workflow_audit_result_path(paths)
    if not path.exists():
        return None
    return WorkflowAuditResult.from_dict(json.loads(path.read_text(encoding="utf-8")))


def persist_workflow_checkpoint_evidence(
    paths: ArbiterPaths,
    *,
    goal_id: str,
    action: str,
    evidence: str,
    source: str,
) -> WorkflowCheckpointEvidence:
    artifact_path = workflow_checkpoint_evidence_path(paths, goal_id, action)
    payload = {
        "goal_id": goal_id,
        "action": action,
        "evidence": evidence.strip(),
        "source": source.strip() or "manual",
        "created_at": utc_now_iso(),
    }
    if not payload["evidence"]:
        raise ValueError("workflow checkpoint evidence must not be empty")
    _atomic_write_text(artifact_path, json.dumps(payload, indent=2, sort_keys=True) + "\n")
    return WorkflowCheckpointEvidence.from_dict(payload, path=artifact_path)


def read_workflow_checkpoint_evidence(paths: ArbiterPaths, goal_id: str, action: str) -> Optional[WorkflowCheckpointEvidence]:
    artifact_path = workflow_checkpoint_evidence_path(paths, goal_id, action)
    if not artifact_path.exists():
        return None
    return WorkflowCheckpointEvidence.from_dict(json.loads(artifact_path.read_text(encoding="utf-8")), path=artifact_path)


def check_deployment_gate(paths: ArbiterPaths) -> List[DeploymentCheck]:
    checks: List[DeploymentCheck] = []
    audit_result = read_workflow_audit_result(paths)
    audit_ok = audit_result is not None and audit_result.passed
    checks.append(DeploymentCheck("audit", audit_ok, "workflow audit result passed" if audit_ok else "deployment gate failed; missing or failing audit result at %s" % workflow_audit_result_path(paths).relative_to(paths.root)))
    checks.extend(_workflow_verification_checks(paths))
    return checks


def load_workflow_state(paths: ArbiterPaths) -> WorkflowSnapshot:
    snapshot = WorkflowPersistence(paths).load()
    queue = WorkflowQueue(paths).snapshot()
    snapshot.active_goal = queue.active
    snapshot.pending_goals = list(queue.pending)
    return snapshot


def update_todo_workflow_section(paths: ArbiterPaths, snapshot: Optional[WorkflowSnapshot] = None) -> Path:
    snapshot = snapshot or load_workflow_state(paths)
    todo_path = paths.path("TODO.md")
    content = todo_path.read_text(encoding="utf-8") if todo_path.exists() else "# TODO\n"
    section = _render_todo_section(snapshot)
    marker = "## Arbiter workflow\n"
    if marker in content:
        start = content.index(marker)
        tail = content[start + len(marker):]
        next_heading = tail.find("\n## ")
        end = len(content) if next_heading == -1 else start + len(marker) + next_heading + 1
        content = content[:start] + section + content[end:]
    else:
        if not content.endswith("\n"):
            content += "\n"
        if content.strip():
            content += "\n"
        content += section
    todo_path.write_text(content.rstrip() + "\n", encoding="utf-8")
    return todo_path


def _render_todo_section(snapshot: WorkflowSnapshot) -> str:
    groups = {
        STATUS_PENDING: [],
        STATUS_IN_PROGRESS: [],
        "Review": [],
        STATUS_COMPLETED: [],
        STATUS_FAILED: [],
    }
    for state in WORKFLOW_SEQUENCE:
        lifecycle = snapshot.phases.get(state.value, PhaseLifecycle(state=state.value))
        bucket = lifecycle.status if lifecycle.status in groups else STATUS_PENDING
        groups[bucket].append(state.value)
    lines = ["## Arbiter workflow", "Current state: %s" % snapshot.current_state.value]
    if snapshot.active_goal is not None:
        lines.append("Active goal: %s (%s, attempt %s/%s)" % (snapshot.active_goal.title, snapshot.active_goal.target_state, snapshot.active_goal.attempts, snapshot.active_goal.max_attempts))
    if snapshot.branch_reason:
        lines.append("Branch: %s" % snapshot.branch_reason)
    if snapshot.next_actions:
        lines.append("Next actions: %s" % ", ".join(snapshot.next_actions))
    if snapshot.required_actions:
        lines.append("Required checkpoints:")
        for action in snapshot.required_actions:
            lines.append("- %s [%s/%s]" % (action.name, action.kind, action.status))
    if snapshot.last_error:
        lines.append("Last error: %s" % snapshot.last_error)
    lines.append("")
    for heading in (STATUS_PENDING, STATUS_IN_PROGRESS, "Review", STATUS_COMPLETED, STATUS_FAILED):
        lines.append("### %s" % heading)
        entries = groups[heading]
        if entries:
            for item in entries:
                lines.append("- %s" % item)
        else:
            lines.append("- none")
        lines.append("")
    return "\n".join(lines)


def _initial_snapshot(paths: ArbiterPaths) -> WorkflowSnapshot:
    inferred = infer_current_state(paths)
    now = utc_now_iso()
    phases: Dict[str, PhaseLifecycle] = {}
    for state in WORKFLOW_SEQUENCE:
        status = STATUS_COMPLETED if state_rank(state) <= state_rank(inferred) else STATUS_PENDING
        phases[state.value] = PhaseLifecycle(
            state=state.value,
            status=status,
            attempts=1 if status == STATUS_COMPLETED else 0,
            entered_at=now if status == STATUS_COMPLETED else None,
            completed_at=now if status == STATUS_COMPLETED else None,
        )
    return WorkflowSnapshot(current_state=inferred, updated_at=now, phases=phases)


def infer_current_state(paths: ArbiterPaths) -> WorkflowState:
    top_level_ok = all(paths.path(rel).exists() for rel in REQUIRED_TOP_LEVEL_DIRS)
    current = WorkflowState.INIT if top_level_ok else WorkflowState.INIT
    if all(check.passed for check in validate_startup(paths)[:2]):
        current = WorkflowState.PLAN
    if check_research_gate(paths).passed:
        current = WorkflowState.RESEARCH
    if check_requirements_gate(paths).passed:
        current = WorkflowState.REQUIREMENTS
    if check_design_gate(paths).passed:
        current = WorkflowState.DESIGN
    if paths.path("arbiter", "cli.py").exists() and paths.path("providers", "base.py").exists():
        current = WorkflowState.IMPLEMENT
    verify_result = read_verify_result(paths)
    if verify_result and verify_result.passed:
        current = WorkflowState.VERIFY
    audit_result = read_workflow_audit_result(paths)
    if audit_result and audit_result.passed:
        current = WorkflowState.AUDIT
    return current


def _last_completed_state(snapshot: WorkflowSnapshot) -> WorkflowState:
    current = WorkflowState.INIT
    for state in WORKFLOW_SEQUENCE:
        lifecycle = snapshot.phases.get(state.value, PhaseLifecycle(state=state.value))
        if lifecycle.status == STATUS_COMPLETED:
            current = state
    return current
