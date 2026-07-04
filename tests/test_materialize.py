from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from arbiter.paths import ArbiterPaths
from providers.claude import ClaudeAdapter
from providers.codex import CodexAdapter
from providers.antigravity import AntigravityAdapter
from tests.helpers import make_repo


class MaterializationTests(unittest.TestCase):
    def test_claude_dry_run_plans_claude_md(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            adapter = ClaudeAdapter(ArbiterPaths(root))
            context = adapter.prepare_context(run_id='test-run', dry_run=True)
            manifest = adapter.materialize_config(context)
            destinations = [action.destination for action in manifest.actions]
            self.assertTrue(any(dest.endswith('/CLAUDE.md') for dest in destinations))
            self.assertTrue(manifest.dry_run)

    def test_codex_write_creates_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            (root / 'codex' / 'config' / 'config.toml').write_text('model = "gpt-test"\n', encoding='utf-8')
            adapter = CodexAdapter(ArbiterPaths(root))
            context = adapter.prepare_context(run_id='test-run', dry_run=False)
            manifest = adapter.materialize_config(context)
            self.assertFalse(manifest.dry_run)
            self.assertTrue((root / 'state' / 'codex' / 'home' / 'config.toml').exists())
            self.assertTrue((root / 'state' / 'arbiter' / 'materializations' / 'test-run' / 'codex-materialization.json').exists())

    def test_antigravity_uses_shadow_config(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            adapter = AntigravityAdapter(ArbiterPaths(root))
            context = adapter.prepare_context(run_id='test-run', dry_run=True)
            manifest = adapter.materialize_config(context)
            self.assertTrue(any('shadow config' in warning for warning in manifest.warnings))


if __name__ == '__main__':
    unittest.main()
