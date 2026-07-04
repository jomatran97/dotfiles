"""Startup validation for Arbiter architecture compliance."""

from __future__ import annotations

from dataclasses import dataclass

from .agents import assert_agent_registry, validate_agent_registry
from .gates import check_design_gate, check_requirements_gate, check_research_gate
from .paths import ArbiterPaths, REQUIRED_PROVIDER_DIRS, REQUIRED_TOP_LEVEL_DIRS


class StartupValidationError(RuntimeError):
    """Raised when mandatory Arbiter startup checks fail."""


@dataclass(frozen=True)
class StartupCheck:
    name: str
    passed: bool
    detail: str


def validate_startup(paths: ArbiterPaths) -> list[StartupCheck]:
    checks: list[StartupCheck] = []
    missing_layout = [rel for rel in (*REQUIRED_TOP_LEVEL_DIRS, *REQUIRED_PROVIDER_DIRS) if not paths.path(rel).exists()]
    checks.append(
        StartupCheck(
            "layout",
            not missing_layout,
            "workspace layout ready" if not missing_layout else "missing workspace paths: %s" % ", ".join(missing_layout),
        )
    )

    registry_issues = list(validate_agent_registry(paths))
    checks.append(
        StartupCheck(
            "agent_registry",
            not registry_issues,
            "agent registry valid" if not registry_issues else "; ".join(registry_issues),
        )
    )

    for result in (check_research_gate(paths), check_requirements_gate(paths), check_design_gate(paths)):
        checks.append(
            StartupCheck(
                f"gate_{result.name}",
                result.passed,
                f"{result.name} gate passed" if result.passed else "missing: %s" % ", ".join(result.missing),
            )
        )

    antigravity_doc = paths.path("research", "antigravity.md")
    antigravity_text = antigravity_doc.read_text(encoding="utf-8") if antigravity_doc.exists() else ""
    complete = all(marker in antigravity_text for marker in (
        "## Official sources reviewed",
        "## CLI model",
        "## Authentication",
        "## Configuration and settings",
        "## Arbiter integration strategy",
    )) and len(antigravity_text.splitlines()) >= 120
    checks.append(
        StartupCheck(
            "research_antigravity_complete",
            complete,
            "research/antigravity.md complete" if complete else "research/antigravity.md missing required verified sections",
        )
    )
    return checks


def assert_startup_valid(paths: ArbiterPaths) -> None:
    checks = validate_startup(paths)
    failures = [check.detail for check in checks if not check.passed]
    if failures:
        raise StartupValidationError("startup validation failed: %s" % "; ".join(failures))
    assert_agent_registry(paths)
