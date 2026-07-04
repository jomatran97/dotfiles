"""Config materialization helpers and manifests."""

from __future__ import annotations

from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
from typing import Any, Optional, Set
from uuid import uuid4


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


@dataclass
class MaterializationAction:
    action: str
    source: Optional[str]
    destination: str
    status: str
    checksum: Optional[str] = None
    detail: Optional[str] = None


@dataclass
class MaterializationManifest:
    provider: str
    run_id: str
    materialization_id: str = field(default_factory=lambda: uuid4().hex)
    timestamp: str = field(default_factory=utc_now_iso)
    dry_run: bool = True
    actions: list[MaterializationAction] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def add(self, action: MaterializationAction) -> None:
        self.actions.append(action)

    def warn(self, message: str) -> None:
        self.warnings.append(message)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    def write(self, path: Path) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.to_dict(), indent=2, sort_keys=True) + "\n", encoding="utf-8")
        return path


def copy_file(manifest: MaterializationManifest, source: Path, destination: Path) -> None:
    checksum = sha256_file(source)
    if manifest.dry_run:
        status = "planned"
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        status = "written"
    manifest.add(MaterializationAction("copy_file", str(source), str(destination), status, checksum))


def ensure_dir(manifest: MaterializationManifest, destination: Path) -> None:
    if manifest.dry_run:
        status = "planned"
    else:
        destination.mkdir(parents=True, exist_ok=True)
        status = "ensured"
    manifest.add(MaterializationAction("ensure_dir", None, str(destination), status))


def copy_tree_contents(
    manifest: MaterializationManifest,
    source_dir: Path,
    destination_dir: Path,
    *,
    skip_names: Optional[Set[str]] = None,
) -> None:
    skip_names = skip_names or {".gitkeep"}
    if not source_dir.exists():
        manifest.warn(f"source directory does not exist: {source_dir}")
        return
    ensure_dir(manifest, destination_dir)
    for source in sorted(source_dir.rglob("*")):
        if source.name in skip_names:
            continue
        rel = source.relative_to(source_dir)
        destination = destination_dir / rel
        if source.is_dir():
            ensure_dir(manifest, destination)
        elif source.is_file():
            copy_file(manifest, source, destination)
