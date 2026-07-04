from __future__ import annotations

from pathlib import Path
import unittest

from arbiter.agents import load_agent_registry, validate_agent_registry
from arbiter.paths import ArbiterPaths


class RepositoryIntegrityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.root = Path(__file__).resolve().parents[1]
        cls.paths = ArbiterPaths(cls.root)

    def test_real_repo_agent_registry_is_clean(self) -> None:
        self.assertEqual(validate_agent_registry(self.paths), ())

    def test_real_repo_has_checked_in_source_templates(self) -> None:
        for rel in (
            'claude/CLAUDE.md',
            'claude/settings/settings.json',
            'codex/agents/AGENTS.md',
            'codex/config/config.toml',
            'arbiter/agent-registry.json',
        ):
            self.assertTrue((self.root / rel).exists(), rel)

    def test_workflow_docs_match_runtime_artifact_names(self) -> None:
        readme = (self.root / 'README.md').read_text(encoding='utf-8')
        deployment = (self.root / 'arbiter' / 'DEPLOYMENT.md').read_text(encoding='utf-8')
        for text in (readme, deployment):
            self.assertIn('verify-result.json', text)
            self.assertIn('audit-result.json', text)
            self.assertIn('phase-artifacts/<goal-id>/index.json', text)
            self.assertIn('phase-artifacts/<goal-id>/archive/', text)
            self.assertNotIn('deployment-audit.json', text)

    def test_authoritative_agent_prompts_are_actionable(self) -> None:
        required_sections = ('## Role', '## Inputs', '## Required output', '## Constraints', '## Handoff')
        for spec in load_agent_registry(self.paths):
            markdown = (self.root / spec.markdown).read_text(encoding='utf-8')
            for section in required_sections:
                self.assertIn(section, markdown, f'{spec.markdown} missing {section}')


if __name__ == '__main__':
    unittest.main()
