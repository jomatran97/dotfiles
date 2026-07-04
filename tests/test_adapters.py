from __future__ import annotations

from pathlib import Path
import os
import tempfile
import unittest
from unittest import mock

from arbiter.paths import ArbiterPaths
from providers.claude import ClaudeAdapter
from providers.codex import CodexAdapter
from providers.antigravity import AntigravityAdapter
from providers.base import ProviderError
from tests.helpers import fake_exe, make_repo


class AdapterTests(unittest.TestCase):
    def test_claude_fake_discovery_auth_and_plan(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'claude', '''
if [[ "${1:-}" == "--version" ]]; then echo "claude fake 1.0"; exit 0; fi
if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" ]]; then echo "--permission-mode --model"; exit 0; fi
echo "ok"
''')
            with mock.patch.dict(os.environ, {'CLAUDE_BIN': str(exe)}):
                adapter = ClaudeAdapter(ArbiterPaths(root))
                readiness = adapter.check_readiness()
                self.assertTrue(readiness.ready)
                context = adapter.prepare_context(run_id='r', dry_run=True)
                plan = adapter.build_command(context, prompt='hello')
                self.assertIn('-p', plan.argv)
                self.assertEqual(plan.env['CLAUDE_CONFIG_DIR'], str(root / 'state' / 'claude' / 'config'))

    def test_codex_fake_plan_uses_safe_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'codex', '''
if [[ "${1:-}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval"; exit 0; fi
echo "ok"
''')
            with mock.patch.dict(os.environ, {'CODEX_BIN': str(exe)}):
                adapter = CodexAdapter(ArbiterPaths(root))
                self.assertTrue(adapter.check_readiness().ready)
                context = adapter.prepare_context(run_id='r', dry_run=True)
                plan = adapter.build_command(context, prompt='hello')
                self.assertIn('workspace-write', plan.argv)
                self.assertIn('on-request', plan.argv)
                with self.assertRaises(ProviderError):
                    adapter.build_command(context, prompt='hello', sandbox='danger-full-access')

    def test_antigravity_requires_detected_print_mode_for_noninteractive(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'agy', '''
if [[ "${1:-}" == "--version" ]]; then echo "agy fake 1.0"; exit 0; fi
if [[ "${1:-}" == "--help" ]]; then echo "usage: agy"; exit 0; fi
echo "ok"
''')
            with mock.patch.dict(os.environ, {'AGY_BIN': str(exe)}):
                adapter = AntigravityAdapter(ArbiterPaths(root))
                context = adapter.prepare_context(run_id='r', dry_run=True)
                with self.assertRaises(ProviderError):
                    adapter.build_command(context, prompt='hello')


if __name__ == '__main__':
    unittest.main()
