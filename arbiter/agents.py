"""Mandatory Arbiter agent registry and markdown validation."""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
from typing import Any, Iterable, Mapping

from .paths import ArbiterPaths

REGISTRY_PATH = "arbiter/agent-registry.json"
ALLOWED_PROVIDERS = ("claude", "codex", "antigravity")
REQUIRED_AGENT_NAMES = (
    "Arbiter",
    "plan",
    "research",
    "requirements",
    "design",
    "implement",
    "build",
    "verify",
    "audit",
    "debug",
    "ideas",
    "scout",
    "trace",
    "craft",
    "deploy",
    "maintenance",
)

EXACT_AGENT_SPECS: dict[str, tuple[str, str, str, str]] = {
    "Arbiter": ("claude", "claude-sonnet-4", "claude/agents/arbiter.md", "Arbiter -> Claude Sonnet"),
    "audit": ("claude", "claude-opus-4.8", "claude/agents/audit.md", "audit -> Claude Opus 4.8"),
    "build": ("codex", "gpt-5.5-codex", "codex/agents/build.md", "build/debug -> GPT-5.5 Codex"),
    "craft": ("antigravity", "gemini-2.5-pro", "antigravity/agents/craft.md", "scout/ideas/craft/trace -> Antigravity"),
    "debug": ("codex", "gpt-5.5-codex", "codex/agents/debug.md", "build/debug -> GPT-5.5 Codex"),
    "ideas": ("antigravity", "gemini-2.5-pro", "antigravity/agents/ideas.md", "scout/ideas/craft/trace -> Antigravity"),
    "scout": ("antigravity", "gemini-2.5-pro", "antigravity/agents/scout.md", "scout/ideas/craft/trace -> Antigravity"),
    "trace": ("antigravity", "gemini-2.5-pro", "antigravity/agents/trace.md", "scout/ideas/craft/trace -> Antigravity"),
}


class AgentRegistryError(ValueError):
    """Raised when the mandatory agent registry is invalid."""


@dataclass(frozen=True)
class AgentSpec:
    name: str
    provider: str
    model: str
    markdown: str
    purpose: str
    required_mapping: str = ""

    def to_dict(self) -> dict[str, str]:
        return {
            "name": self.name,
            "provider": self.provider,
            "model": self.model,
            "markdown": self.markdown,
            "purpose": self.purpose,
            "required_mapping": self.required_mapping,
        }


def _parse_frontmatter(text: str) -> dict[str, str]:
    lines = text.splitlines()
    if len(lines) < 3 or lines[0].strip() != "---":
        raise AgentRegistryError("missing markdown frontmatter")
    data: dict[str, str] = {}
    for line in lines[1:]:
        stripped = line.strip()
        if stripped == "---":
            return data
        if ":" not in line:
            raise AgentRegistryError(f"invalid frontmatter line: {line!r}")
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip().strip('"').strip("'")
    raise AgentRegistryError("unterminated markdown frontmatter")


def _coerce_entry(data: Mapping[str, Any]) -> AgentSpec:
    spec = AgentSpec(
        name=str(data["name"]).strip(),
        provider=str(data["provider"]).strip(),
        model=str(data["model"]).strip(),
        markdown=str(data["markdown"]).strip(),
        purpose=str(data.get("purpose", "")).strip(),
        required_mapping=str(data.get("required_mapping") or "").strip(),
    )
    if spec.provider not in ALLOWED_PROVIDERS:
        raise AgentRegistryError(f"agent {spec.name!r} uses unsupported provider {spec.provider!r}")
    if not spec.model:
        raise AgentRegistryError(f"agent {spec.name!r} is missing a model mapping")
    if not spec.markdown.endswith(".md"):
        raise AgentRegistryError(f"agent {spec.name!r} markdown must be a .md file")
    return spec


def load_agent_registry(paths: ArbiterPaths) -> tuple[AgentSpec, ...]:
    registry_path = paths.path(REGISTRY_PATH)
    if not registry_path.exists():
        raise AgentRegistryError(f"missing mandatory agent registry: {REGISTRY_PATH}")
    raw = json.loads(registry_path.read_text(encoding="utf-8"))
    if not isinstance(raw, list) or not raw:
        raise AgentRegistryError("agent registry must be a non-empty JSON array")
    specs = tuple(_coerce_entry(item) for item in raw)
    names = [spec.name for spec in specs]
    if len(names) != len(set(names)):
        raise AgentRegistryError("agent registry contains duplicate agent names")
    missing = sorted(set(REQUIRED_AGENT_NAMES) - set(names))
    extra = sorted(set(names) - set(REQUIRED_AGENT_NAMES))
    if missing:
        raise AgentRegistryError("agent registry is missing required agents: %s" % ", ".join(missing))
    if extra:
        raise AgentRegistryError("agent registry contains unexpected agents: %s" % ", ".join(extra))
    return specs


def agent_names(paths: ArbiterPaths) -> tuple[str, ...]:
    return tuple(spec.name for spec in load_agent_registry(paths))


def get_agent_spec(paths: ArbiterPaths, name: str) -> AgentSpec:
    key = name.strip().lower()
    for spec in load_agent_registry(paths):
        if spec.name.lower() == key:
            return spec
    raise AgentRegistryError(f"unknown agent {name!r}")


def _iter_provider_agent_markdown(paths: ArbiterPaths) -> Iterable[Path]:
    for provider in ALLOWED_PROVIDERS:
        directory = paths.path(provider, "agents")
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*.md")):
            yield path


def validate_agent_registry(paths: ArbiterPaths) -> tuple[str, ...]:
    issues: list[str] = []
    try:
        specs = load_agent_registry(paths)
    except (json.JSONDecodeError, KeyError, TypeError, AgentRegistryError) as exc:
        return (str(exc),)

    authoritative_by_name = {spec.name.lower(): spec for spec in specs}
    authoritative_by_markdown = {spec.markdown: spec for spec in specs}

    for spec in specs:
        expected = EXACT_AGENT_SPECS.get(spec.name)
        if expected is not None:
            expected_provider, expected_model, expected_markdown, expected_mapping = expected
            if spec.provider != expected_provider or spec.model != expected_model or spec.markdown != expected_markdown:
                issues.append(
                    f"agent {spec.name!r} must map exactly to {expected_provider}/{expected_model} via {expected_markdown}"
                )
            if spec.required_mapping != expected_mapping:
                issues.append(
                    f"agent {spec.name!r} required_mapping must be {expected_mapping!r}, found {spec.required_mapping!r}"
                )
        markdown_path = paths.path(spec.markdown)
        if not markdown_path.exists():
            issues.append(f"agent {spec.name!r} missing markdown: {spec.markdown}")
            continue
        text = markdown_path.read_text(encoding="utf-8").strip()
        if len(text) < 180:
            issues.append(f"agent {spec.name!r} markdown is too short to be a real instruction file")
            continue
        try:
            frontmatter = _parse_frontmatter(text)
        except AgentRegistryError as exc:
            issues.append(f"agent {spec.name!r} markdown invalid: {exc}")
            continue
        exact = {
            "agent": spec.name,
            "provider": spec.provider,
            "model": spec.model,
        }
        for key, expected in exact.items():
            actual = frontmatter.get(key)
            if actual != expected:
                issues.append(
                    f"agent {spec.name!r} markdown field {key!r} must be {expected!r}, found {actual!r}"
                )
        if f"# {spec.name.title()} agent" not in text and f"# {spec.name} agent" not in text.lower():
            issues.append(f"agent {spec.name!r} markdown missing canonical heading")

    for markdown_path in _iter_provider_agent_markdown(paths):
        rel = str(markdown_path.relative_to(paths.root))
        if rel in authoritative_by_markdown:
            continue
        text = markdown_path.read_text(encoding="utf-8").strip()
        if not text.startswith("---"):
            continue
        try:
            frontmatter = _parse_frontmatter(text)
        except AgentRegistryError as exc:
            issues.append(f"extra agent markdown {rel!r} invalid: {exc}")
            continue
        frontmatter_agent = (frontmatter.get("agent") or "").strip()
        if not frontmatter_agent:
            issues.append(f"extra agent markdown {rel!r} must declare an agent name in frontmatter")
            continue
        provider = (frontmatter.get("provider") or "").strip()
        parent_provider = Path(rel).parts[0]
        if provider and provider != parent_provider:
            issues.append(
                f"extra agent markdown {rel!r} declares provider {provider!r} but lives under {parent_provider!r}"
            )
        spec = authoritative_by_name.get(frontmatter_agent.lower())
        if spec is not None:
            issues.append(
                f"non-authoritative agent prompt {rel!r} conflicts with registered agent {spec.name!r}; authoritative path is {spec.markdown}"
            )
    return tuple(issues)


def assert_agent_registry(paths: ArbiterPaths) -> None:
    issues = validate_agent_registry(paths)
    if issues:
        raise AgentRegistryError("; ".join(issues))
