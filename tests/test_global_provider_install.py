from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts' / 'install-global-provider-config'


class GlobalProviderInstallSmokeTests(unittest.TestCase):
    def run_script(
        self,
        *args: str,
        home: Path,
        root: Path = ROOT,
        script: Path = SCRIPT,
    ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env['HOME'] = str(home)
        return subprocess.run(
            [str(script), *args],
            cwd=root,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def test_help_lists_safety_flags(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            result = self.run_script('--help', home=Path(td))
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('--dry-run', output)
            self.assertIn('--force', output)
            self.assertIn('--backup-dir', output)
            self.assertIn('~/.gemini', output)

    def test_dry_run_uses_temp_home_without_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            result = self.run_script('--dry-run', home=home)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('Summary:', output)
            self.assertIn('.claude/agents', output)
            self.assertIn('.codex/AGENTS.md', output)
            self.assertIn('shared global Gemini state', output)
            self.assertEqual(list(home.iterdir()), [])

    def test_force_install_to_temp_home_creates_backup_before_overwrite(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / 'home'
            backups = Path(td) / 'backups'
            target = home / '.codex' / 'AGENTS.md'
            target.parent.mkdir(parents=True)
            target.write_text('old codex guidance\n', encoding='utf-8')

            result = self.run_script('--force', '--backup-dir', str(backups), home=home)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertTrue(target.exists())
            self.assertIn('Codex agents', target.read_text(encoding='utf-8'))
            backup = backups / '.codex' / 'AGENTS.md'
            self.assertTrue(backup.exists(), output)
            self.assertEqual(backup.read_text(encoding='utf-8'), 'old codex guidance\n')

    def test_force_preserves_existing_antigravity_shared_file_without_backup(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            repo = Path(td) / 'repo'
            home = Path(td) / 'home'
            backups = Path(td) / 'backups'
            script = repo / 'scripts' / 'install-global-provider-config'
            source = repo / 'antigravity' / 'settings' / 'hooks.json'
            target = home / '.gemini' / 'config' / 'hooks.json'

            script.parent.mkdir(parents=True)
            source.parent.mkdir(parents=True)
            shutil.copy2(SCRIPT, script)
            source.write_text('{"hooks": []}\n', encoding='utf-8')
            target.parent.mkdir(parents=True)
            target.write_text('{"unknown": true}\n', encoding='utf-8')

            result = self.run_script(
                '--force',
                '--backup-dir',
                str(backups),
                home=home,
                root=repo,
                script=script,
            )
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertEqual(target.read_text(encoding='utf-8'), '{"unknown": true}\n')
            self.assertIn('preserving existing shared Gemini state', output)
            self.assertFalse((backups / '.gemini' / 'config' / 'hooks.json').exists(), output)

    def test_directory_destination_is_warned_and_skipped_for_file_target(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / 'home'
            backups = Path(td) / 'backups'
            target = home / '.codex' / 'AGENTS.md'
            target.mkdir(parents=True)

            result = self.run_script('--force', '--backup-dir', str(backups), home=home)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertTrue(target.is_dir())
            self.assertFalse((target / 'AGENTS.md').exists(), output)
            self.assertIn('directory or symlink to a directory', output)
            self.assertFalse((backups / '.codex' / 'AGENTS.md').exists(), output)

    def test_symlink_to_file_destination_is_warned_and_skipped_without_backup(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / 'home'
            backups = Path(td) / 'backups'
            referent = Path(td) / 'existing-agent.md'
            target = home / '.codex' / 'AGENTS.md'

            referent.write_text('keep this file\n', encoding='utf-8')
            target.parent.mkdir(parents=True)
            target.symlink_to(referent)

            result = self.run_script('--force', '--backup-dir', str(backups), home=home)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertTrue(target.is_symlink())
            self.assertEqual(referent.read_text(encoding='utf-8'), 'keep this file\n')
            self.assertIn('symlink to a file or other non-directory', output)
            self.assertFalse((backups / '.codex' / 'AGENTS.md').exists(), output)

    def test_parent_path_file_conflict_warns_and_skips_only_that_target(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / 'home'
            backups = Path(td) / 'backups'
            conflict = home / '.claude'
            codex_target = home / '.codex' / 'AGENTS.md'

            home.mkdir(parents=True)
            conflict.write_text('not a directory\n', encoding='utf-8')

            result = self.run_script('--force', '--backup-dir', str(backups), home=home)
            output = result.stdout + result.stderr
            self.assertEqual(result.returncode, 0, output)
            self.assertTrue(conflict.is_file())
            self.assertIn('parent path component is not a directory or symlink to a directory', output)
            self.assertFalse((home / '.claude' / 'settings.json').exists(), output)
            self.assertTrue(codex_target.exists(), output)
            self.assertIn('Codex agents', codex_target.read_text(encoding='utf-8'))
            self.assertFalse((backups / '.claude').exists(), output)


if __name__ == '__main__':
    unittest.main()
