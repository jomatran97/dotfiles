"""Provider registry."""

from __future__ import annotations

from typing import Type

from arbiter.paths import ArbiterPaths
from providers.base import BaseProviderAdapter
from providers.claude import ClaudeAdapter
from providers.codex import CodexAdapter
from providers.antigravity import AntigravityAdapter

ADAPTERS: dict[str, Type[BaseProviderAdapter]] = {
    "claude": ClaudeAdapter,
    "codex": CodexAdapter,
    "antigravity": AntigravityAdapter,
}


def provider_names() -> tuple[str, ...]:
    return tuple(sorted(ADAPTERS))


def get_adapter(name: str, paths: ArbiterPaths) -> BaseProviderAdapter:
    key = name.lower()
    try:
        return ADAPTERS[key](paths)
    except KeyError as exc:
        raise ValueError(f"unknown provider {name!r}; expected one of: {', '.join(provider_names())}") from exc
