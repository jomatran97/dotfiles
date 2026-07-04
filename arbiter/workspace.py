"""Runtime workspace management."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from uuid import uuid4

from .paths import ArbiterPaths


def new_run_id(provider: str) -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"{provider}-{stamp}-{uuid4().hex[:8]}"


@dataclass(frozen=True)
class RunWorkspace:
    provider: str
    run_id: str
    root: Path
    workspace: Path
    artifacts: Path
    logs: Path
    manifest_dir: Path


class WorkspaceManager:
    def __init__(self, paths: ArbiterPaths) -> None:
        self.paths = paths

    def prepare(self, provider: str, *, run_id: Optional[str] = None, create: bool = True) -> RunWorkspace:
        rid = run_id or new_run_id(provider)
        provider_state = self.paths.provider_state_dir(provider)
        run_root = self.paths.state_dir / "arbiter" / "runs" / rid
        workspace = provider_state / "workspaces" / rid
        artifacts = provider_state / "artifacts" / rid
        logs = self.paths.provider_log_dir(provider)
        manifest_dir = self.paths.state_dir / "arbiter" / "materializations" / rid
        if create:
            for directory in (run_root, workspace, artifacts, logs, manifest_dir):
                directory.mkdir(parents=True, exist_ok=True)
        return RunWorkspace(
            provider=provider,
            run_id=rid,
            root=run_root,
            workspace=workspace,
            artifacts=artifacts,
            logs=logs,
            manifest_dir=manifest_dir,
        )
