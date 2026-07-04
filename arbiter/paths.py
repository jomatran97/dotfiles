"""Path helpers for the Arbiter repository and runtime layout."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional, Union

REQUIRED_PROVIDER_DIRS = (
    "claude/settings",
    "claude/agents",
    "claude/skills",
    "claude/hooks",
    "claude/mcp",
    "codex/config",
    "codex/prompts",
    "codex/agents",
    "codex/templates",
    "antigravity/settings",
    "antigravity/agents",
    "antigravity/prompts",
    "antigravity/artifacts",
    "providers/claude",
    "providers/codex",
    "providers/antigravity",
)

REQUIRED_TOP_LEVEL_DIRS = (
    "arbiter",
    "research",
    "state",
    "logs",
    "scripts",
)

REQUIRED_RESEARCH_FILES = (
    "research/claude.md",
    "research/codex.md",
    "research/antigravity.md",
)


@dataclass(frozen=True)
class ArbiterPaths:
    """Resolved repository paths."""

    root: Path

    @classmethod
    def discover(cls, start: Optional[Path] = None) -> "ArbiterPaths":
        """Discover the repository root.

        If `start` is omitted, the package location is used. Discovery walks upward
        until it finds `research/` and `arbiter/`.
        """

        current = (start or Path(__file__).resolve()).resolve()
        if current.is_file():
            current = current.parent
        for candidate in (current, *current.parents):
            if (candidate / "arbiter").is_dir() and (candidate / "research").is_dir():
                return cls(candidate)
        # Fallback for early bootstrap: package parent.
        return cls(Path(__file__).resolve().parents[1])

    def path(self, *parts: Union[str, Path]) -> Path:
        return self.root.joinpath(*parts)

    @property
    def state_dir(self) -> Path:
        return self.path("state")

    @property
    def logs_dir(self) -> Path:
        return self.path("logs")

    def provider_source_dir(self, provider: str) -> Path:
        return self.path(provider)

    def provider_state_dir(self, provider: str) -> Path:
        return self.state_dir / provider

    def provider_log_dir(self, provider: str) -> Path:
        return self.logs_dir / provider

    def ensure_standard_layout(self) -> None:
        for rel in (*REQUIRED_TOP_LEVEL_DIRS, *REQUIRED_PROVIDER_DIRS):
            directory = self.path(rel)
            directory.mkdir(parents=True, exist_ok=True)
            gitkeep = directory / ".gitkeep"
            if not gitkeep.exists() and not any(directory.iterdir()):
                gitkeep.touch()

    def missing(self, rel_paths: Iterable[str]) -> list[Path]:
        return [self.path(rel) for rel in rel_paths if not self.path(rel).exists()]
