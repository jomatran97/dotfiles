from __future__ import annotations

import contextlib
import io
import json
from pathlib import Path
import os
import tempfile
import unittest
from unittest import mock

from arbiter.cli import main
from tests.helpers import fake_exe, make_repo


class CliRunTests(unittest.TestCase):
    def test_run_requires_registered_agent(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'codex', '''
if [[ "${1:-}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval --model"; exit 0; fi
echo "ok"
''')
            with mock.patch.dict(os.environ, {'CODEX_BIN': str(exe)}):
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'run', 'codex', '--prompt', 'hello', '--json'])
                self.assertEqual(code, 1, stdout.getvalue())
                payload = json.loads(stdout.getvalue())
                self.assertIn('run requires --agent', payload['message'])

    def test_run_rejects_provider_agent_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'claude', '''
if [[ "${1:-}" == "--version" ]]; then echo "claude fake 1.0"; exit 0; fi
if [[ "${1:-}" == "auth" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" ]]; then echo "--permission-mode --model -p auth mcp"; exit 0; fi
echo "ok"
''')
            with mock.patch.dict(os.environ, {'CLAUDE_BIN': str(exe)}):
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'run', 'claude', '--agent', 'build', '--prompt', 'hello', '--json'])
                self.assertEqual(code, 1, stdout.getvalue())
                payload = json.loads(stdout.getvalue())
                self.assertIn("mapped to provider 'codex'", payload['message'])


if __name__ == '__main__':
    unittest.main()
