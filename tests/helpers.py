from __future__ import annotations

from pathlib import Path
import os
import shutil
import stat

TEMPLATE_ROOT = Path(__file__).resolve().parents[1]


def make_repo(root: Path) -> None:
    for directory in [
        'arbiter', 'research', 'state', 'logs', 'scripts',
        'claude/settings', 'claude/agents', 'claude/skills', 'claude/hooks', 'claude/mcp',
        'codex/config', 'codex/prompts', 'codex/agents', 'codex/templates',
        'antigravity/settings', 'antigravity/agents', 'antigravity/prompts', 'antigravity/artifacts',
        'providers/claude', 'providers/codex', 'providers/antigravity',
        'tests',
    ]:
        (root / directory).mkdir(parents=True, exist_ok=True)
    for file in [
        'research/claude.md', 'research/codex.md', 'research/antigravity.md',
        'arbiter/REQUIREMENTS.md', 'arbiter/DESIGN.md', 'arbiter/MAINTENANCE.md', 'arbiter/DEPLOYMENT.md', 'arbiter/TESTING.md',
        'arbiter/agent-registry.json',
        'claude/CLAUDE.md',
        'claude/settings/settings.json',
        'claude/agents/arbiter.md', 'claude/agents/plan.md', 'claude/agents/requirements.md', 'claude/agents/design.md', 'claude/agents/audit.md', 'claude/agents/deploy.md',
        'codex/config/config.toml',
        'codex/agents/implement.md', 'codex/agents/build.md', 'codex/agents/debug.md', 'codex/agents/verify.md', 'codex/agents/AGENTS.md',
        'antigravity/agents/research.md', 'antigravity/agents/scout.md', 'antigravity/agents/ideas.md', 'antigravity/agents/trace.md', 'antigravity/agents/craft.md', 'antigravity/agents/maintenance.md',
    ]:
        source = TEMPLATE_ROOT / file
        target = root / file
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.exists():
            shutil.copy2(source, target)
        else:
            target.write_text(f'# {file}\n', encoding='utf-8')
    (root / 'TODO.md').write_text('# TODO\n', encoding='utf-8')


def fake_exe(path: Path, body: str) -> Path:
    if path.exists() and path.is_dir():
        path = path / 'fake-cli'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('#!/usr/bin/env bash\nset -euo pipefail\n' + body, encoding='utf-8')
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return path
