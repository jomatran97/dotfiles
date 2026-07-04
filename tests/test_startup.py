from __future__ import annotations

from pathlib import Path
import tempfile
import unittest

from arbiter.agents import get_agent_spec, load_agent_registry
from arbiter.paths import ArbiterPaths
from arbiter.startup import validate_startup
from tests.helpers import make_repo


class StartupValidationTests(unittest.TestCase):
    def test_startup_validation_passes_for_compliant_repo(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            checks = validate_startup(ArbiterPaths(root))
            self.assertTrue(all(check.passed for check in checks), checks)

    def test_startup_validation_fails_on_agent_mapping_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            audit_md = root / 'claude' / 'agents' / 'audit.md'
            audit_md.write_text(audit_md.read_text(encoding='utf-8').replace('claude-opus-4.8', 'wrong-model'), encoding='utf-8')
            checks = validate_startup(ArbiterPaths(root))
            self.assertFalse(all(check.passed for check in checks))
            details = ' | '.join(check.detail for check in checks)
            self.assertIn('wrong-model', details)

    def test_startup_validation_fails_on_conflicting_non_authoritative_prompt(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            conflict = root / 'claude' / 'agents' / 'debug.md'
            conflict.write_text("""---\nagent: debug\nprovider: claude\nmodel: claude-sonnet-4\n---\n# Debug agent\n\nConflicting prompt.\n""", encoding='utf-8')
            checks = validate_startup(ArbiterPaths(root))
            self.assertFalse(all(check.passed for check in checks))
            details = ' | '.join(check.detail for check in checks)
            self.assertIn('non-authoritative agent prompt', details)

    def test_required_exact_mappings_are_present(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            make_repo(root)
            paths = ArbiterPaths(root)
            self.assertEqual((get_agent_spec(paths, 'scout').provider, get_agent_spec(paths, 'scout').model), ('antigravity', 'gemini-2.5-pro'))
            self.assertEqual((get_agent_spec(paths, 'ideas').provider, get_agent_spec(paths, 'ideas').model), ('antigravity', 'gemini-2.5-pro'))
            self.assertEqual((get_agent_spec(paths, 'craft').provider, get_agent_spec(paths, 'craft').model), ('antigravity', 'gemini-2.5-pro'))
            self.assertEqual((get_agent_spec(paths, 'trace').provider, get_agent_spec(paths, 'trace').model), ('antigravity', 'gemini-2.5-pro'))
            self.assertEqual((get_agent_spec(paths, 'build').provider, get_agent_spec(paths, 'build').model), ('codex', 'gpt-5.5-codex'))
            self.assertEqual((get_agent_spec(paths, 'debug').provider, get_agent_spec(paths, 'debug').model), ('codex', 'gpt-5.5-codex'))
            self.assertEqual((get_agent_spec(paths, 'audit').provider, get_agent_spec(paths, 'audit').model), ('claude', 'claude-opus-4.8'))
            self.assertEqual((get_agent_spec(paths, 'Arbiter').provider, get_agent_spec(paths, 'Arbiter').model), ('claude', 'claude-sonnet-4'))
            specs = {spec.name: spec for spec in load_agent_registry(paths)}
            self.assertEqual(specs['scout'].required_mapping, 'scout/ideas/craft/trace -> Antigravity')
            self.assertEqual(specs['ideas'].required_mapping, 'scout/ideas/craft/trace -> Antigravity')
            self.assertEqual(specs['craft'].required_mapping, 'scout/ideas/craft/trace -> Antigravity')
            self.assertEqual(specs['trace'].required_mapping, 'scout/ideas/craft/trace -> Antigravity')
            self.assertEqual(specs['build'].required_mapping, 'build/debug -> GPT-5.5 Codex')
            self.assertEqual(specs['debug'].required_mapping, 'build/debug -> GPT-5.5 Codex')
            self.assertEqual(specs['audit'].required_mapping, 'audit -> Claude Opus 4.8')
            self.assertEqual(specs['Arbiter'].required_mapping, 'Arbiter -> Claude Sonnet')
            readme = (Path(__file__).resolve().parents[1] / 'README.md').read_text(encoding='utf-8')
            self.assertIn('`scout/ideas/craft/trace -> Antigravity`', readme)
            self.assertIn('`build/debug -> GPT-5.5 Codex`', readme)
            self.assertIn('`audit -> Claude Opus 4.8`', readme)
            self.assertIn('`Arbiter -> Claude Sonnet`', readme)


if __name__ == '__main__':
    unittest.main()
