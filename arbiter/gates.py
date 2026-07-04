"""Workflow gate checks."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .paths import ArbiterPaths, REQUIRED_RESEARCH_FILES


@dataclass(frozen=True)
class GateResult:
    name: str
    passed: bool
    missing: tuple[str, ...]

    def raise_if_failed(self) -> None:
        if not self.passed:
            missing = ", ".join(self.missing)
            raise RuntimeError(f"{self.name} gate failed; missing: {missing}")


def _rel(paths: ArbiterPaths, missing: list[Path]) -> tuple[str, ...]:
    return tuple(str(path.relative_to(paths.root)) for path in missing)


def check_research_gate(paths: ArbiterPaths) -> GateResult:
    missing = paths.missing(REQUIRED_RESEARCH_FILES)
    return GateResult("research", not missing, _rel(paths, missing))


def check_requirements_gate(paths: ArbiterPaths) -> GateResult:
    missing = paths.missing(("arbiter/REQUIREMENTS.md",))
    return GateResult("requirements", not missing, _rel(paths, missing))


def check_design_gate(paths: ArbiterPaths) -> GateResult:
    missing = paths.missing(("arbiter/DESIGN.md",))
    return GateResult("design", not missing, _rel(paths, missing))


def check_pre_implementation_gates(paths: ArbiterPaths) -> list[GateResult]:
    return [check_research_gate(paths), check_requirements_gate(paths), check_design_gate(paths)]


def assert_pre_implementation_gates(paths: ArbiterPaths) -> None:
    for result in check_pre_implementation_gates(paths):
        result.raise_if_failed()
