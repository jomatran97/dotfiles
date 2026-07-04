from __future__ import annotations

import contextlib
import gc
import io
import json
from pathlib import Path
import os
import signal
import tempfile
import time
import unittest
import warnings
from unittest import mock

from arbiter.cli import main
from arbiter.hcom import HCOMEnvelope, HCOMType, build_task_envelope, envelope
from arbiter.paths import ArbiterPaths
from arbiter.session_store import SessionStore
from tests.helpers import fake_exe, make_repo


class HCOMTests(unittest.TestCase):
    def test_envelope_roundtrip(self) -> None:
        msg = envelope(
            message_type=HCOMType.TASK_SUBMIT,
            source='arbiter',
            target='claude',
            payload={'prompt': 'hello'},
            run_id='run-1',
        )
        data = json.loads(msg.to_json())
        parsed = HCOMEnvelope.from_dict(data)
        self.assertEqual(parsed.type, 'task.submit')
        self.assertEqual(parsed.correlation_id, msg.correlation_id)

    def test_task_envelope_uses_exact_registry_mapping(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            task = build_task_envelope(ArbiterPaths(root), agent='build', prompt='hello', goal='verify', run_id='run-1')
            self.assertEqual(task.provider, 'codex')
            self.assertEqual(task.model, 'gpt-5.5-codex')
            self.assertEqual(task.agent, 'build')
            self.assertEqual(task.isolation.mode, 'provider-workspace-isolation')

    def test_hcom_send_uses_registered_provider_and_model(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'codex', '''
if [[ "${1:-}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval --model"; exit 0; fi
printf '%s\n' "$*"
''')
            with mock.patch.dict(os.environ, {'CODEX_BIN': str(exe)}):
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'send', 'build', '--prompt', 'hello', '--json'])
                self.assertEqual(code, 0, stdout.getvalue())
                payload = json.loads(stdout.getvalue())['payload']
                self.assertIn('--model gpt-5.5-codex', payload['stdout'])
                self.assertEqual(payload['task']['provider'], 'codex')

    def test_hcom_kill_stops_detached_session_and_cleans_store(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            pid_file = root / 'child.pid'
            exe = fake_exe(root / 'codex', f'''
if [[ "${{1:-}}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${{1:-}}" == "login" && "${{2:-}}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${{1:-}}" == "--help" || "${{2:-}}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval --model"; exit 0; fi
trap 'kill 0; exit 0' TERM
sleep 30 &
echo $! > {pid_file}
wait
''')
            with mock.patch.dict(os.environ, {'CODEX_BIN': str(exe)}):
                with warnings.catch_warnings(record=True) as caught:
                    warnings.simplefilter('always', ResourceWarning)
                    stdout = io.StringIO()
                    with contextlib.redirect_stdout(stdout):
                        code = main(['--root', str(root), 'hcom', 'send', 'build', '--prompt', 'hello', '--detach', '--json'])
                    self.assertEqual(code, 0, stdout.getvalue())
                    send_data = json.loads(stdout.getvalue())
                    session_id = send_data['payload']['session_id']
                    pid = send_data['payload']['pid']
                    pgid = send_data['payload']['pgid']
                    self.assertEqual(SessionStore(ArbiterPaths(root)).get(session_id).pgid, pgid)
                    stdout = io.StringIO()
                    with contextlib.redirect_stdout(stdout):
                        code = main(['--root', str(root), 'hcom', 'kill', session_id, '--json'])
                    self.assertEqual(code, 0, stdout.getvalue())
                    kill_data = json.loads(stdout.getvalue())
                    self.assertEqual(kill_data['type'], 'session.stopped')
                    self.assertIsNone(SessionStore(ArbiterPaths(root)).get(session_id))
                    child_pid = int(pid_file.read_text(encoding='utf-8').strip())
                    gc.collect()
                resource_warnings = [item for item in caught if issubclass(item.category, ResourceWarning)]
                self.assertEqual(resource_warnings, [], resource_warnings)
                for proc_pid in (pid, child_pid):
                    with self.assertRaises(ProcessLookupError):
                        os.kill(proc_pid, 0)

    def test_detached_session_natural_exit_is_reconciled(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'codex', '''
if [[ "${1:-}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval --model"; exit 0; fi
sleep 0.2
''')
            with mock.patch.dict(os.environ, {'CODEX_BIN': str(exe)}):
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'send', 'build', '--prompt', 'hello', '--detach', '--json'])
                self.assertEqual(code, 0, stdout.getvalue())
                send_data = json.loads(stdout.getvalue())
                session_id = send_data['payload']['session_id']
                pid = send_data['payload']['pid']
                time.sleep(0.6)
                store = SessionStore(ArbiterPaths(root))
                self.assertIsNone(store.get(session_id))
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)

    def test_detached_immediate_exit_reconciles_without_crashing(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'codex', '''
if [[ "${1:-}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval --model"; exit 0; fi
exit 0
''')
            with mock.patch.dict(os.environ, {'CODEX_BIN': str(exe)}):
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'send', 'build', '--prompt', 'hello', '--detach', '--json'])
                self.assertEqual(code, 0, stdout.getvalue())
                send_data = json.loads(stdout.getvalue())
                session_id = send_data['payload']['session_id']
                time.sleep(0.2)
                store = SessionStore(ArbiterPaths(root))
                self.assertIsNone(store.get(session_id))
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'kill', session_id, '--json'])
                self.assertEqual(code, 2, stdout.getvalue())
                self.assertEqual(json.loads(stdout.getvalue())['error'], 'session_not_found')

    def test_stale_token_mismatch_session_reconciles_before_kill_exposure(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'codex', '''
if [[ "${1:-}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval --model"; exit 0; fi
sleep 30
''')
            with mock.patch.dict(os.environ, {'CODEX_BIN': str(exe)}):
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'send', 'build', '--prompt', 'hello', '--detach', '--json'])
                self.assertEqual(code, 0, stdout.getvalue())
                send_data = json.loads(stdout.getvalue())
                session_id = send_data['payload']['session_id']
                store = SessionStore(ArbiterPaths(root))
                record = store.get(session_id)
                self.assertIsNotNone(record)
                Path(record.live_token_path).write_text('tampered\n', encoding='utf-8')
                os.kill(record.pid, 0)
                self.assertEqual(store.list(), ())
                self.assertIsNone(store.get(session_id))
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'kill', session_id, '--json'])
                self.assertEqual(code, 2, stdout.getvalue())
                payload = json.loads(stdout.getvalue())
                self.assertEqual(payload['error'], 'session_not_found')
                os.kill(record.pid, 0)
                os.killpg(record.pgid, signal.SIGKILL)
                time.sleep(0.2)
                self.assertIsNone(store.get(session_id))

    def test_stale_missing_token_session_reconciles_before_kill_exposure(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'codex', '''
if [[ "${1:-}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval --model"; exit 0; fi
sleep 30
''')
            with mock.patch.dict(os.environ, {'CODEX_BIN': str(exe)}):
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'send', 'build', '--prompt', 'hello', '--detach', '--json'])
                self.assertEqual(code, 0, stdout.getvalue())
                send_data = json.loads(stdout.getvalue())
                session_id = send_data['payload']['session_id']
                store = SessionStore(ArbiterPaths(root))
                record = store.get(session_id)
                self.assertIsNotNone(record)
                Path(record.live_token_path).unlink()
                os.kill(record.pid, 0)
                self.assertEqual(store.list(), ())
                self.assertIsNone(store.get(session_id))
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'kill', session_id, '--json'])
                self.assertEqual(code, 2, stdout.getvalue())
                self.assertEqual(json.loads(stdout.getvalue())['error'], 'session_not_found')
                os.kill(record.pid, 0)
                os.killpg(record.pgid, signal.SIGKILL)
                time.sleep(0.2)
                self.assertIsNone(store.get(session_id))

    def test_tokenless_persisted_session_reconciles_before_kill_exposure(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'codex', '''
if [[ "${1:-}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval --model"; exit 0; fi
sleep 30
''')
            with mock.patch.dict(os.environ, {'CODEX_BIN': str(exe)}):
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'send', 'build', '--prompt', 'hello', '--detach', '--json'])
                self.assertEqual(code, 0, stdout.getvalue())
                send_data = json.loads(stdout.getvalue())
                session_id = send_data['payload']['session_id']
                store = SessionStore(ArbiterPaths(root))
                record = store.get(session_id)
                self.assertIsNotNone(record)
                raw = json.loads(store.path.read_text(encoding='utf-8'))
                raw[session_id]['session_token'] = ''
                raw[session_id]['live_token_path'] = ''
                store.path.write_text(json.dumps(raw, indent=2, sort_keys=True) + '\n', encoding='utf-8')
                os.kill(record.pid, 0)
                self.assertEqual(store.list(), ())
                self.assertIsNone(store.get(session_id))
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'kill', session_id, '--json'])
                self.assertEqual(code, 2, stdout.getvalue())
                self.assertEqual(json.loads(stdout.getvalue())['error'], 'session_not_found')
                os.kill(record.pid, 0)
                os.killpg(record.pgid, signal.SIGKILL)
                time.sleep(0.2)
                self.assertIsNone(store.get(session_id))

    def test_hcom_kill_keeps_session_record_when_stop_fails(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            exe = fake_exe(root / 'codex', '''
if [[ "${1:-}" == "--version" ]]; then echo "codex fake 1.0"; exit 0; fi
if [[ "${1:-}" == "login" && "${2:-}" == "status" ]]; then echo "logged in"; exit 0; fi
if [[ "${1:-}" == "--help" || "${2:-}" == "--help" ]]; then echo "exec --json --sandbox --ask-for-approval --model"; exit 0; fi
trap '' TERM
sleep 30
''')
            with mock.patch.dict(os.environ, {'CODEX_BIN': str(exe)}):
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'send', 'build', '--prompt', 'hello', '--detach', '--json'])
                self.assertEqual(code, 0, stdout.getvalue())
                send_data = json.loads(stdout.getvalue())
                session_id = send_data['payload']['session_id']
                store = SessionStore(ArbiterPaths(root))
                record = store.get(session_id)
                self.assertIsNotNone(record)
                with mock.patch('providers.base.ProcessSupervisor.terminate', return_value=False), mock.patch('providers.base.ProcessSupervisor.kill', return_value=False):
                    stdout = io.StringIO()
                    with contextlib.redirect_stdout(stdout):
                        code = main(['--root', str(root), 'hcom', 'kill', session_id, '--json'])
                self.assertEqual(code, 2)
                self.assertIsNotNone(store.get(session_id))
                os.killpg(record.pgid, signal.SIGKILL)
                time.sleep(0.2)
                self.assertIsNone(store.get(session_id))
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = main(['--root', str(root), 'hcom', 'kill', session_id, '--json'])
                self.assertEqual(code, 2, stdout.getvalue())
                self.assertEqual(json.loads(stdout.getvalue())['error'], 'session_not_found')


if __name__ == '__main__':
    unittest.main()
